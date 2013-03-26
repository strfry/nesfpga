from myhdl import *

NES_CLK_period = 46 * 12
#  constant AC97_CLK_period : time := 20.833333333333332 us; -- 48 kHz
#  constant CLK_period : time := 46.560848137510206 ns; -- 21.477272 MhZ

def APU_Pulse(
		CLK,
		APU_CE,

		TimerLoad,

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
				timer.next = TimerLoad
			else:
				timer.next = timer - 1

	return logic

def APU_Triangle(
		CLK,
		APU_CE,

		TimerLoad,

		PCM_OUT
		):
	
	lut = [15, 14, 13, 12, 11, 10,  9,  8,  7,  6,  5,  4,  3,  2,  1,  0, 0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15]
	sequencer = Signal(0)
	timer = Signal(intbv(0))

	@always(CLK.posedge)
	def logic():
		if APU_CE:
			if timer == 0:
				sequencer.next = (sequencer + 1) % 32
				PCM_OUT.next = lut[sequencer]
				#timer.next = TimerLoad
				timer.next = 0x0fd
			else:
				timer.next = timer - 1

	return logic

