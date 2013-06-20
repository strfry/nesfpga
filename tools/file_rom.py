from myhdl import *

rom = tuple(map(lambda c: ord(c), file("smb.nes").read()))
rom = rom[:8192]

def file_rom(clk, address, data, CONTENT):

	@always(clk.posedge)
	def logic():
		data.next = CONTENT[int(address)]

	return logic

