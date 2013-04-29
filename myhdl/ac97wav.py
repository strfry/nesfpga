from myhdl import *

from clk_util import *

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

