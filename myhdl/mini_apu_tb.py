from myhdl import *
from mini_apu import *
from cpu_bus import CPU_Bus


NES_CLK_period = 46
#  constant AC97_CLK_period : time := 20.833333333333332 us; -- 48 kHz
#  constant CLK_period : time := 46.560848137510206 ns; -- 21.477272 MhZ

def CLK_Gen(CLK, period):
        @always(delay(period / 2))
        def gen():
                CLK.next = not CLK

        return gen

def AC97_WavWriter(PCM, filename):
        import wave
        outfile = wave.open(filename, 'w')
        outfile.setnchannels(1)
        outfile.setframerate(48000)
        outfile.setsampwidth(1)

	CLK = Signal()

        AC97_CLK_period = 20833

        ac97_clk_gen = CLK_Gen(CLK, AC97_CLK_period)

        @always(CLK.posedge)
        def writeSample():
                outfile.writeframes(chr(int(PCM) * 4))

        return ac97_clk_gen, writeSample


def APU_TB():
	PCM = Signal(intbv()[8:])
	cpu_bus = CPU_Bus()


        CLK_cnt = Signal(intbv())
	@always(cpu_bus.CLK.posedge)
	def clk_cnt():
                CLK_cnt.next = (CLK_cnt + 1) % 12

        @always_comb
        def ce():
                cpu_bus.PHI2 = CLK_cnt == 5

	clk_gen = CLK_Gen(cpu_bus.CLK, NES_CLK_period)
	ac97 = AC97_WavWriter(PCM, "mini.wav")
	apu = APU_Main(cpu_bus, PCM)


	bar = Signal(intbv())
	@always(delay(10000000))
	def foo():
		bar.next = bar + 5
		cpu_bus.fake_write(0x4002, bar)
		print "increase"

	return instances(), cpu_bus.instances

Simulation(APU_TB()).run()
