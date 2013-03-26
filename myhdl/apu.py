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

