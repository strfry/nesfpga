from myhdl import *

rom = tuple(map(lambda c: ord(c), file("smb.nes").read()))
rom = rom[:8192]

def file_rom(clk, address, data, CONTENT):

	@always(clk.posedge)
	def logic():
		data.next = CONTENT[int(address)]

	return logic

def convert():
	clk = Signal(bool())
	a = Signal(intbv()[13:0])
	d = Signal(intbv()[8:0])

	toVHDL(file_rom, clk, a, d, rom)
	#conversion.analyze(file_rom, clk, a, d)
	


convert()
