from myhdl import *

from file_rom import file_rom

def str2bin(s):
	return tuple(map(lambda c: ord(c), s))

rom_file = file("smb.nes")
rom_header = rom_file.read(16)
rom_prg = str2bin(rom_file.read(2**15))
rom_chr = str2bin(rom_file.read(2**13))

def CartridgeROM(
		CLK,
		RSTN,
		PRG_Address,
		PRG_Data,
		CHR_Address,
		CHR_Data
		):

	PRG = file_rom(CLK, PRG_Address, PRG_Data, rom_prg)
	CHR = file_rom(CLK, CHR_Address, CHR_Data, rom_chr)

	return PRG, CHR



def convert():
	clk = Signal(bool())
	rstn = Signal(bool())
	prg_address = Signal(intbv()[15:0])
	prg_data = Signal(intbv()[8:0])
	chr_address = Signal(intbv()[14:0])
	chr_data = Signal(intbv()[8:0])

	toVerilog(CartridgeROM, clk, rstn, prg_address, prg_data, chr_address, chr_data)
	


convert()
