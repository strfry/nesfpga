from py65.memory import ObservableMemory
from py65.devices.mpu6502 import MPU

class NSFParser:
	def __init__(self, bytes):
		#import pdb; pdb.set_trace()
		assert bytes[0:5] == 'NESM\x1a', "Not a NSF File"
		assert bytes[5] == 1, "NSF Version != 0x01"
		
		self.num_songs = bytes[6]
		self.start_song = bytes[7]
		self.load_addr = bytes[0x08] + 0x100 * bytes[0x09]
		self.init_addr = bytes[0x0a] + 0x100 * bytes[0x0b]
		self.play_addr = bytes[0x0c] + 0x100 * bytes[0x0d]
		
		self.info_name = bytes[0x0e:0x2e].decode('ascii')
		self.info_artist = bytes[0x2e:0x4e].decode('ascii')
		self.info_copyright = bytes[0x4e:0x6e].decode('ascii')
		
		self.ntsc_ticks = bytes[0x6e] + 0x100 * bytes[0x6f]
		self.pal_ticks = bytes[0x78] + 0x100 * bytes[0x79]
		
		assert bytes[0x7a] == 0x00, "Not a NTSC Tune"
		assert bytes[0x7b] == 0x00, "Extra Sound Chips are not supported"
		
		assert bytes[0x70:0x78] == '\x00\x00\x00\x00\x00\x00\x00\x00', "Bank switching not supported at this time"
		
		self.data = bytes[0x80:]


class NSFSoftCPU:
	NES_CLK_period = 46 * 12

	def __init__(self, filename):
		self.nsf = NSFParser(bytearray(file(filename).read()))

		# Set up Memory with Hooks
		self.mem = ObservableMemory()
		self.mem.write(self.nsf.load_addr, self.nsf.data)
		self.cpu = MPU(self.mem)
		self.deltaCallTime = 0
		self.totalCycles = 0

	def subscribe_to_write(self, range, callback):
		self.mem.subscribe_to_write(range, callback)

	# Call NSF Init code
	def setup(self, start_song = -1):
		if start_song == -1:
			start_song = self.nsf.start_song - 1

		# Push a special address -1 to the stack to implement function calls
		self.cpu.stPushWord(0x1337 - 1)

		# NSF Style init call
		self.cpu.a = start_song
		self.cpu.x = 0
		self.cpu.pc = self.nsf.init_addr

		while self.cpu.pc != 0x1337:
			self.cpu.step()

	# Execute 1 CPU Step, or wait to until enough cycles have passed
	def play_cycle(self):
		self.deltaCallTime = self.deltaCallTime + NES_CLK_period

		check_frame()
		if self.cpu.pc != 0x1337:
			self.totalCycles = self.totalCycles + 1
			if self.totalCycles == self.cpu.processorCycles:
				self.cpu.step()


	# Internal: Check if frame is completed and restart it periodically
	def check_frame(self):
		if self.cpu.pc == 0x1337:
			frame_time = self.nsf.ntsc_ticks * 1000
			if self.deltaCallTime >= frame_time:
				self.deltaCallTime = self.deltaCallTime - frame_time
				self.cpu.stPushWord(0x1337 - 1)
				self.cpu.pc = self.nsf.play_addr
				print "Frame Completed"


