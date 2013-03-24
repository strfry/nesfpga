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
		

nsf = NSFParser(bytearray(file("smb.nsf").read()))

# Set up Memory with Hooks

mem = ObservableMemory()
mem.write(nsf.load_addr, nsf.data)

def apu_write(address, value):
	print "APU Write at %08X: %08x" % (address, value)

def apu_read(address):
	print "APU Read at %08X" % (address)
	return 0


mem.subscribe_to_write(range(0x4000, 0x4020), apu_write)
mem.subscribe_to_read(range(0x4000, 0x4020), apu_read)

# Instantiate CPU

cpu = MPU(mem)

# Push a special address -1 to the stack to implement function calls
cpu.stPushWord(0x1337 - 1)

# NSF Style init call
cpu.a = nsf.start_song - 1
cpu.x = 0
cpu.pc = nsf.init_addr

while cpu.pc != 0x1337:
	#print cpu
	cpu.step()

# Initialization complete, now call play method repeatedly

while True:
	cpu.stPushWord(0x1337 - 1)
	cpu.pc = nsf.play_addr

	while cpu.pc != 0x1337:
		cpu.step()

	print "Frame Completed"
