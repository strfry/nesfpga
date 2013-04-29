"""
	Minimal Testbench with an APU_Pulse unit that is sweeped via CPU_Bus writes
	The generated sweep can be used to implement a FIR filter in AC97_Writer
"""

from myhdl import *
from mini_apu import *
from cpu_bus import CPU_Bus
from ac97wav import AC97_WavWriter


NES_CLK_period = 46 # ns
#  constant AC97_CLK_period : time := 20.833333333333332 us; -- 48 kHz
#  constant CLK_period : time := 46.560848137510206 ns; -- 21.477272 MhZ

def CLK_Gen(CLK, period):
        @always(delay(period / 2))
        def gen():
                CLK.next = not CLK

        return gen

def APU_TB():
	PCM = Signal(intbv()[8:])
	cpu_bus = CPU_Bus()

        CLK_cnt = Signal(intbv())
	@always(cpu_bus.CLK.posedge)
	def clk_cnt():
                CLK_cnt.next = (CLK_cnt + 1) % 12

        @always_comb
        def ce():
                cpu_bus.PHI2.next = CLK_cnt == 5
		cpu_bus.PHI2.next = True

	clk_gen = CLK_Gen(cpu_bus.CLK, NES_CLK_period * 12)
	ac97 = AC97_WavWriter(PCM, "mini.wav")
	apu = APU_Main(cpu_bus.CLK, cpu_bus.PHI2, cpu_bus.RW10,
		cpu_bus.Address, cpu_bus.Data_write, PCM)


	sweepTimer = Signal(intbv()[11:0])

	@instance
	def sweep():
		for i in range(0x7ff):
			sweepTimer = intbv(i)
			cpu_bus.fake_write(0x4002, sweepTimer[8:0])
			cpu_bus.fake_write(0x4003, sweepTimer[11:8])
		
			# Print new frequency
			pulse_period = (sweepTimer + 1) * NES_CLK_period * 12 * 8 *  10**-9
			frequency = 1.0 / (pulse_period * 2)
		
			print "Increasing period to %d cycles, (%f Hz)" % (sweepTimer, frequency)

			# Walk through lower period ranges faster to emulate an exponential sweep
			import math
			octave = int(math.log(frequency, 2))

			yield delay(100000000 / (i+1))
		raise StopSimulation

		

	return instances(), cpu_bus.instances

def convert():
	cpu_bus = CPU_Bus()
	pcm = Signal(intbv()[8])
	toVHDL(APU_Main, cpu_bus.CLK, cpu_bus.PHI2, cpu_bus.RW10,
		cpu_bus.Address, cpu_bus.Data_write,
		pcm)

#convert()
Simulation(APU_TB()).run()
