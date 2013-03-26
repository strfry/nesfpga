from py65.memory import ObservableMemory
from py65.devices.mpu6502 import MPU

from apu import *

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
#mem.subscribe_to_read(range(0x4000, 0x4020), apu_read)

# Instantiate CPU

cpu = MPU(mem)

# Push a special address -1 to the stack to implement function calls
cpu.stPushWord(0x1337 - 1)

# NSF Style init call
cpu.a = nsf.start_song - 1
cpu.x = 0
cpu.pc = nsf.init_addr

while cpu.pc != 0x1337:
	cpu.step()

# Initialization complete, now call play method the first time
cpu.stPushWord(0x1337 - 1)
cpu.pc = nsf.play_addr


def clk_gen(CLK, period):
	@always(delay(period))
	def gen():
		CLK.next = not CLK

	return gen


def AC97_WavWriter(CLK, PCM, filename):
	import wave
	outfile = wave.open(filename, 'w')
	outfile.setnchannels(1)
	outfile.setframerate(48000)
	outfile.setsampwidth(1)

	AC97_CLK_period = 20833

	ac97_clk_gen = clk_gen(CLK, AC97_CLK_period)

	@always(CLK.posedge)
	def writeSample():
		outfile.writeframes(chr(int(PCM) * 4))

	return ac97_clk_gen, writeSample

def TestBench():
	NES_CLK = Signal(False)
	AC97_CLK = Signal(False)
	APU_CE = Signal(False)
	PCM = Signal(intbv()[8:])

	Pulse1Timer = Signal(intbv())
	Pulse2Timer = Signal(intbv())
	TriangleTimer = Signal(intbv())
	
	Pulse1PCM = Signal(intbv()[4:])
	Pulse2PCM = Signal(intbv()[4:])
	TrianglePCM = Signal(intbv()[4:])

	@always_comb
	def comb():
		PCM.next = Pulse1PCM + Pulse2PCM + TrianglePCM
		#PCM.next = TrianglePCM

	nes_clk_gen = clk_gen(NES_CLK, NES_CLK_period)
	pulse1 = APU_Pulse(NES_CLK, APU_CE, Pulse1Timer, Pulse1PCM)
	pulse2 = APU_Pulse(NES_CLK, APU_CE, Pulse2Timer, Pulse2PCM)
	triangle = APU_Triangle(NES_CLK, APU_CE, TriangleTimer, TrianglePCM)
	ac97 = AC97_WavWriter(AC97_CLK, PCM, "pulse.wav")

	num_cycles = Signal(cpu.processorCycles)
	deltaCallTime = Signal(0)

	@always(NES_CLK.posedge)
	def ce():
		APU_CE.next = not APU_CE
		#import pdb; pdb.set_trace()


		deltaCallTime.next = deltaCallTime + NES_CLK_period

		#print deltaCallTime, nsf.ntsc_ticks * 1000
		#print num_cycles, cpu.processorCycles

		if deltaCallTime >= nsf.ntsc_ticks * 1000 and cpu.pc==0x1337:
			deltaCallTime.next = deltaCallTime - nsf.ntsc_ticks * 1000
			cpu.stPushWord(0x1337 - 1)
			cpu.pc = nsf.play_addr
			print "Frame Completed"

		if cpu.pc != 0x1337:
			num_cycles.next = num_cycles + 1
			if num_cycles == cpu.processorCycles:
				cpu.step()
				
				timer_low = intbv(mem[0x4002])[8:0]
				timer_high = intbv(mem[0x4003])[3:0]

				Pulse1Timer.next = concat(timer_high, timer_low)

				timer_low = intbv(mem[0x4006])[8:0]
				timer_high = intbv(mem[0x4007])[3:0]

				Pulse2Timer.next = concat(timer_high, timer_low)
				
				timer_low = intbv(mem[0x400a])[8:0]
				timer_high = intbv(mem[0x400b])[3:0]

				TriangleTimer.next = concat(timer_high, timer_low)

	#foo = traceSignals(APU_Pulse, NES_CLK, APU_CE, PCM)

	return pulse1, pulse2, triangle, ac97, nes_clk_gen, ce, comb

Simulation(TestBench()).run()

