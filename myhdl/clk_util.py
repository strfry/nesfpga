from myhdl import *

def CLK_Gen(CLK, period):
        @always(delay(period / 2))
        def gen():
                CLK.next = not CLK

        return gen

