from myhdl import *

from cpu_bus import CPU_Bus


def APU_Pulse(
	CLK, PHI2, RW10, Address, Data_write,
	ChipSelect,
	PCM_out):

	DutyCycle = Signal(intbv()[2:0])
	LengthCounterHalt = Signal(False)
	Envelope = Signal(intbv()[5:0])

	TimerLoad = Signal(intbv()[11:0])

	sequencer = Signal(intbv("00001111"))
	timer = Signal(intbv()[11:0])

	@always(CLK.posedge)
	def logic():
		if PHI2 and RW10 == 0:
			if Address == 0x4000:
				DutyCycle.next = Data_write[8:6]
				LengthCounterHalt.next = Data_write[6]
				Envelope.next = Data_write[5:0]
			elif Address == 0x4001:
				# Sweep unit unimplemented
				pass
			elif Address == 0x4002:
				TimerLoad.next[8:0] = Data_write
			elif Address == 0x4003:
				TimerLoad.next[11:8] = Data_write[3:0]
		if PHI2:
			if timer == 0:
				sequencer.next = concat(sequencer[0], sequencer[8:1])
				PCM_out.next = 0xf if sequencer[0] else 0x00
				#print sequencer
				timer.next = TimerLoad
			else:
				timer.next = timer - 1
	return logic
