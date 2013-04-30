"""
	Minimal Testbench with an APU_Pulse unit that is sweeped via CPU_Bus writes
	The generated sweep can be used to implement a FIR filter in AC97_Writer
"""

from myhdl import *
from apu import APU_Main
from cpu_bus import CPU_Bus
from ac97wav import AC97_WavWriter
from clk_util import CLK_Gen
from nsf import NSFSoftCPU


NES_CLK_period = 46 # ns
#  constant AC97_CLK_period : time := 20.833333333333332 us; -- 48 kHz
#  constant CLK_period : time := 46.560848137510206 ns; -- 21.477272 MhZ

def APU_TB():
	APU_Interrupt = Signal(False)
	PCM = Signal(intbv()[8:])
	cpu_bus = CPU_Bus()

	clk_gen = CLK_Gen(cpu_bus.CLK, NES_CLK_period * 12)
	cpu_bus.PHI2 = Signal(True)

	ac97 = AC97_WavWriter(PCM, "smb.wav")
	apu = APU_Main(cpu_bus.CLK, Signal(True), cpu_bus.PHI2, cpu_bus.RW10,
		cpu_bus.Address, cpu_bus.Data_read, cpu_bus.Data_write,
		APU_Interrupt, PCM)

	cpu = NSFSoftCPU("smb.nsf")
	cpu.subscribe_to_write(range(0x4000, 0x4017), cpu_bus.fake_write)


	cpu.setup()

	@always(cpu_bus.CLK.posedge)
	def cpu_step():
		cpu.play_cycle()

	return instances(), cpu_bus.instances

def convert():
	cpu_bus = CPU_Bus()
	phi1 = Signal(False)
	interrupt = Signal(False)
	pcm = Signal(intbv()[8])
	toVHDL(APU_Main, cpu_bus.CLK, phi1, cpu_bus.PHI2, cpu_bus.RW10,
		cpu_bus.Address, cpu_bus.Data_read, cpu_bus.Data_write,
		interrupt, pcm)

#convert()
Simulation(APU_TB()).run()
