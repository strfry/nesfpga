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
cpu.a = nsf.start_song - 1  + 1
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

	FrameCounterMode = Signal(False)
	InterruptInhibit = Signal(False)

	QuarterFrame_CE = Signal(False)
	HalfFrame_CE = Signal(False)
	InterruptFlag = Signal(False)

	Pulse1Timer = Signal(intbv())
	Pulse2Timer = Signal(intbv())
	TriangleTimer = Signal(intbv())
	
	Pulse1PCM = Signal(intbv()[4:])
	Pulse2PCM = Signal(intbv()[4:])
	TrianglePCM = Signal(intbv()[4:])
	NoisePCM = Signal(intbv()[4:])

	
	Pulse1Timer = Signal(intbv())
	Pulse1Duty = Signal(intbv()[2:0])
	Pulse1StartFlag = Signal(False)
	Pulse1LoopFlag = Signal(False)
	Pulse1ConstantFlag = Signal(False)
	Pulse1Mode = Signal(False)
	Pulse1Length = Signal(intbv())
	Pulse1Volume = Signal(intbv()[4:0])
	Pulse1EnvelopeVolume = Signal(intbv()[4:0])

	Pulse1Envelope = Signal(intbv())

	def pulse1_writehook(address, data):
		data = intbv(data)[8:0]
		if address == 0x4000:
			Pulse1Duty.next = data[8:6]
			Pulse1LoopFlag.next = data[5]
			Pulse1ConstantFlag.next = data[4]
			Pulse1Volume.next = data[4:0]
		elif address == 0x4002:
			Pulse1Timer.next[8:0] = data
			Pulse1Mode.next = data[7]
		elif address == 0x4003:
			Pulse1Length.next = data[8:3]
			Pulse1Timer.next[11:8] = data[3:0]
			Pulse1StartFlag.next = True
			print "Start Pulse1 Envelope"

	mem.subscribe_to_write(range(0x4000, 0x4004), pulse1_writehook)

	
	Pulse2Timer = Signal(intbv())
	Pulse2Duty = Signal(intbv()[2:0])
	Pulse2StartFlag = Signal(False)
	Pulse2LoopFlag = Signal(False)
	Pulse2ConstantFlag = Signal(False)
	Pulse2Mode = Signal(False)
	Pulse2Length = Signal(intbv())
	Pulse2Volume = Signal(intbv()[4:0])
	Pulse2EnvelopeVolume = Signal(intbv()[4:0])

	Pulse2Envelope = Signal(intbv())

	def pulse2_writehook(address, data):
		data = intbv(data)[8:0]
		if address == 0x4004:
			Pulse2Duty.next = data[8:6]
			Pulse2LoopFlag.next = data[5]
			Pulse2ConstantFlag.next = data[4]
			Pulse2Volume.next = data[4:0]
		elif address == 0x4006:
			Pulse2Timer.next[8:0] = data
			Pulse2Mode.next = data[7]
		elif address == 0x4007:
			Pulse2Length.next = data[8:3]
			Pulse2Timer.next[11:8] = data[3:0]
			Pulse2StartFlag.next = True
			print "Start Pulse2 Envelope"

	mem.subscribe_to_write(range(0x4004, 0x4008), pulse2_writehook)


	NoiseTimer = Signal(intbv())
	NoiseStartFlag = Signal(False)
	NoiseLoopFlag = Signal(False)
	NoiseConstantFlag = Signal(False)
	NoiseMode = Signal(False)
	NoiseLength = Signal(intbv())
	NoiseVolume = Signal(intbv()[4:0])
	NoiseEnvelopeVolume = Signal(intbv()[4:0])
	
	def noise_writehook(address, data):
		print "Noise writehook"
		data = intbv(data)
		if address == 0x400c:
			NoiseLoopFlag.next = data[5]
			NoiseConstantFlag.next = data[4]
			NoiseVolume.next = data[4:0]
		elif address == 0x400e:
			NoiseMode.next = data[7]
			NoiseTimer.next = data[4:0]
		elif address == 0x400f:
			NoiseLength.next = data[8:3]
			NoiseStartFlag.next = True
			print "Noise Channel started"

	mem.subscribe_to_write(range(0x400c, 0x4010), noise_writehook)


	@always_comb
	def comb():
		PCM.next = Pulse1PCM + Pulse2PCM + NoisePCM
		#PCM.next = TrianglePCM

	nes_clk_gen = clk_gen(NES_CLK, NES_CLK_period)

	frameCounter = APU_FrameCounter(NES_CLK, APU_CE, FrameCounterMode, InterruptInhibit, QuarterFrame_CE, HalfFrame_CE, InterruptFlag)

	pulse1Envelope = APU_Envelope(NES_CLK, HalfFrame_CE, Pulse1StartFlag, Pulse1LoopFlag, Pulse1ConstantFlag, Pulse1Length, Pulse1Volume, Pulse1EnvelopeVolume)
	pulse2Envelope = APU_Envelope(NES_CLK, HalfFrame_CE, Pulse2StartFlag, Pulse2LoopFlag, Pulse2ConstantFlag, Pulse2Length, Pulse2Volume, Pulse2EnvelopeVolume)
	noiseEnvelope = APU_Envelope(NES_CLK, HalfFrame_CE, NoiseStartFlag, NoiseLoopFlag, NoiseConstantFlag, NoiseLength, NoiseVolume, NoiseEnvelopeVolume)

	pulse1 = APU_Pulse(NES_CLK, APU_CE, Pulse1EnvelopeVolume, Pulse1Duty, Pulse1Timer, Pulse1PCM)
	pulse2 = APU_Pulse(NES_CLK, APU_CE, Pulse2EnvelopeVolume, Pulse2Duty, Pulse2Timer, Pulse2PCM)
	triangle = APU_Triangle(NES_CLK, APU_CE, TriangleTimer, TrianglePCM)
	noise = APU_Noise(NES_CLK, APU_CE, NoiseEnvelopeVolume, NoiseTimer, NoiseMode, NoisePCM)


	# noiseEnvelope(NES_CLK, )


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

				FrameCounterMode.next = intbv(mem[0x4017])[7]
				InterruptInhibit.next = intbv(mem[0x4017])[6]
								
				timer_low = intbv(mem[0x400a])[8:0]
				timer_high = intbv(mem[0x400b])[3:0]

				TriangleTimer.next = concat(timer_high, timer_low)


	#foo = traceSignals(APU_Pulse, NES_CLK, APU_CE, PCM)

	return pulse1, pulse2, triangle, noise, ac97, nes_clk_gen, ce, comb, frameCounter, noiseEnvelope, pulse1Envelope, pulse2Envelope

def TestBench2():
	NES_CLK = Signal(False)
	AC97_CLK = Signal(False)
	PHI1_CE = Signal(False)
	PHI2_CE = Signal(False)
	PCM = Signal(intbv()[8:])

	Address = Signal(intbv()[16:])
	Data_w = Signal(intbv()[8:])
	Data_r = Signal(intbv()[8:])

	APU_Interrupt = Signal(False)


	apu = APU_Main(NES_CLK, PHI1_CE, PHI2_CE,
		Address, Data_w, Data_r, APU_Interrupt, PCM)

	return apu



Simulation(TestBench2()).run()

