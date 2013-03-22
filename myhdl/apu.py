from myhdl import *

NES_CLK_period = 46 * 12
#  constant AC97_CLK_period : time := 20.833333333333332 us; -- 48 kHz
#  constant CLK_period : time := 46.560848137510206 ns; -- 21.477272 MhZ

def APU_Pulse(
		CLK,
		APU_CE,
		PCM_OUT
	):
	
	note = 0x0FD

	sequencer = Signal(intbv("00001111"))
	timer = Signal(intbv(0))

	@always(CLK.posedge)
	def logic():
		if APU_CE:
			#print timer
			if timer == 0:
				sequencer.next = concat(sequencer[0], sequencer[8:1])
				PCM_OUT.next = 0x0f if sequencer[0] else 0x00
				timer.next = note
			else:
				timer.next = timer - 1

	return logic

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
		print PCM
		outfile.writeframes(chr(int(PCM) * 16))

	return ac97_clk_gen, writeSample

def TestBench():
	NES_CLK = Signal(False)
	AC97_CLK = Signal(False)
	APU_CE = Signal(False)
	PCM = Signal(intbv()[4:])

	nes_clk_gen = clk_gen(NES_CLK, NES_CLK_period)
	pulse1 = APU_Pulse(NES_CLK, APU_CE, PCM)
	ac97 = AC97_WavWriter(AC97_CLK, PCM, "pulse.wav")

	@always(NES_CLK.posedge)
	def ce():
		APU_CE.next = not APU_CE

	#foo = traceSignals(APU_Pulse, NES_CLK, APU_CE, PCM)

	return pulse1, ac97, nes_clk_gen, ce

Simulation(TestBench()).run()

