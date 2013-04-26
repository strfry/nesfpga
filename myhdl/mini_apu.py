from myhdl import *

from cpu_bus import CPU_Bus


def APU_Main(cpu_bus, PCM_out):
#	TimerLoad = 0x0FD
	TimerLoad = Signal(intbv())

	sequencer = Signal(intbv("00001111"))
	timer = Signal(intbv(0))

	@always(cpu_bus.CLK.posedge)
	def logic():
		if cpu_bus.PHI2 and cpu_bus.RW10 == 0:
			if cpu_bus.Address == 0x4002:
				TimerLoad.next[8:] = cpu_bus.Data_out
			elif cpu_bus.Address == 0x4003:
				TimerLoad.next[11:8] = cpu_bus.Data_out[3:0]


		if cpu_bus.PHI2:
			if timer == 0:
				sequencer.next = concat(sequencer[0], sequencer[8:1])
				PCM_out.next = 0xf if sequencer[0] else 0x00
				timer.next = TimerLoad
#				timer.next = 0x7f1
			else:
				timer.next = timer - 1

	return logic
