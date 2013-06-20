from myhdl import *

from apu import APU_Main
from cpu_bus import CPU_Bus

def convert():
        cpu_bus = CPU_Bus()
        interrupt = Signal(False)
        pcm = Signal(intbv()[8:0])
        toVerilog(APU_Main, cpu_bus.CLK, cpu_bus.RSTN, cpu_bus.PHI2_CE, cpu_bus.RW10,
                cpu_bus.Address, cpu_bus.Data_read, cpu_bus.Data_write,
                interrupt, pcm)

convert()
