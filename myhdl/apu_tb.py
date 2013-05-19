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

import sys
import os

#assert len(sys.argv) >= 2, "Usage: {} FILE.NSF [SONGNUMBER]".format(sys.argv[0])
rom_filename = sys.argv[1]
base_filename, _ = os.path.splitext(rom_filename)
start_song = 0 if len(sys.argv) < 3 else sys.argv[2]
wav_filename = "output/{}-{}.wav".format(base_filename, start_song)

def APU_TB():
	APU_Interrupt = Signal(False)
	PCM = Signal(intbv()[8:])
	cpu_bus = CPU_Bus()

	clk_gen = CLK_Gen(cpu_bus.CLK, NES_CLK_period)
	cpu_bus.PHI2_CE = Signal(True)
	phi2_cnt = Signal(0)
	

	ac97 = AC97_WavWriter(PCM, wav_filename)
	apu = APU_Main(cpu_bus.CLK, cpu_bus.RSTN, cpu_bus.PHI2_CE, cpu_bus.RW10,
		cpu_bus.Address, cpu_bus.Data_read, cpu_bus.Data_write,
		APU_Interrupt, PCM)

	cpu = NSFSoftCPU(rom_filename)
	cpu.subscribe_to_write(range(0x4000, 0x4017), cpu_bus.fake_write)


	cpu.setup(int(start_song))

	@always(cpu_bus.CLK.posedge)
	def cpu_step():
		if cpu_bus.PHI2_CE:
			cpu.play_cycle()

		phi2_cnt.next = (phi2_cnt + 1) % 12
		cpu_bus.PHI2_CE.next = phi2_cnt == 0

	return instances(), cpu_bus.instances

Simulation(APU_TB()).run()
