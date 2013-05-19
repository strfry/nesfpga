#!/usr/bin/env python

# Set up Xilinx environment variable

XILINX_SETTINGS_PATH = "/opt/Xilinx/14.5/ISE_DS/settings64.sh"

def shell_source(script):
    """Sometime you want to emulate the action of "source" in bash,
    settings some environment variables. Here is a way to do it."""
    import subprocess, os
    pipe = subprocess.Popen(". %s; env" % script, stdout=subprocess.PIPE, shell=True)
    output = pipe.communicate()[0]
    print output
    env = zip((line.split("=", 1) for line in output.splitlines()))
    os.environ.update(env)

#shell_source(XILINX_SETTINGS_PATH)

from xilinx import Fpga, Xilinx

# Specify UCF-like pin mappings

fpga = Fpga()
fpga.ucf_file = "nes_top.ucf"
fpga.setDevice('virtex5', 'xc5vlx50t', 'ff1136', '-2')

fpga.setPin("clk", "AG18")
fpga.setPin("rstn", "E7")
fpga.setPin("HDMIHSYNC", "H8")
fpga.setPin("HDMIVSYNC", "F13")
fpga.setPin("HDMIDE", "V10")
fpga.setPin("HDMICLKP", "K11")
fpga.setPin("HDMICLKN", "J11")
fpga.setPin("HDMID<0>", "G10")
fpga.setPin("HDMID<1>", "G8")
fpga.setPin("HDMID<2>", "B12")
fpga.setPin("HDMID<3>", "D12")
fpga.setPin("HDMID<4>", "C12")
fpga.setPin("HDMID<5>", "D11")
fpga.setPin("HDMID<6>", "F10")
fpga.setPin("HDMID<7>", "D10")
fpga.setPin("HDMID<8>", "E9")
fpga.setPin("HDMID<9>", "F9")
fpga.setPin("HDMID<10>", "E8")
fpga.setPin("HDMID<11>", "F8")
fpga.setPin("HDMISCL", "U8")
fpga.setPin("HDMISDA", "V8")
fpga.setPin("HDMIRSTN", "AF23")
fpga.setPin("AUDCLK", "AH17")
fpga.setPin("AUDSDI", "AE18")
fpga.setPin("AUDSDO", "AG20")
fpga.setPin("AUDSYNC", "J9")
fpga.setPin("AUDRST", "E12")
fpga.setPin("Led<0>", "AG8")
fpga.setPin("Led<1>", "AH8")
fpga.setPin("Led<2>", "AH9")
fpga.setPin("Led<3>", "AG10")
fpga.setPin("Led<4>", "AH10")
fpga.setPin("Led<5>", "AG11")
fpga.setPin("Led<6>", "AF11")
fpga.setPin("Led<7>", "AE11")
fpga.setPin("BTN<0>", "G6")
fpga.setPin("BTN<1>", "G7")
fpga.setPin("BTN<2>", "E6")
fpga.setPin("BTN<3>", "J17")
fpga.setPin("BTN<4>", "H15")
fpga.setPin("BTN<5>", "K19")
fpga.setPin("BTN<6>", "J21")
fpga.setPin("sw<0>", "J19")
fpga.setPin("sw<1>", "L18")
fpga.setPin("sw<2>", "K18")
fpga.setPin("sw<3>", "H18")
fpga.setPin("sw<4>", "H17")
fpga.setPin("sw<5>", "K17")
fpga.setPin("sw<6>", "G16")
fpga.setPin("sw<7>", "G15")
fpga.setPin("JA<0>", "AD11")
fpga.setPin("JA<1>", "AD9")
fpga.setPin("JA<2>", "AM13")
fpga.setPin("JA<3>", "AM12")
fpga.setPin("JA<4>", "AD10")
fpga.setPin("JA<5>", "AE8")
fpga.setPin("JA<6>", "AF10")
fpga.setPin("JA<7>", "AJ11")
fpga.setPin("JB<0>", "AE9")
fpga.setPin("JB<1>", "AC8")
fpga.setPin("JB<2>", "AB10")
fpga.setPin("JB<3>", "AC9")
fpga.setPin("JB<4>", "AF8")
fpga.setPin("JB<5>", "AB8")
fpga.setPin("JB<6>", "AA10")
fpga.setPin("JB<7>", "AA9")

print fpga

# Specify build files

_ = '../'

imp = Xilinx('build', 'Genesys_NES')
imp.setFpga(fpga)

# Add HDL Files

# Top File for Digilent Genesys Board
imp.addHdl(_ + './Genesys_NES.vhd')

# NES Core
imp.addHdl(_ + './NES_Pack.vhd')
imp.addHdl(_ + './NES_Mainboard.vhd')

# Cartridge Module for coregen files
imp.addHdl(_ + 'CartridgeROM_Coregen.vhd')

# Coregen files for Super Mario
imp.addHdl(_ + 'Coregen/chr_rom_smb.ngc')
imp.addHdl(_ + 'Coregen/prg_rom_smb.ngc')

# NES CPU
imp.addHdl(_ + './NES_2A03/T65.vhd')
imp.addHdl(_ + './NES_2A03/SRAM.vhd')
imp.addHdl(_ + './NES_2A03/T65_ALU.vhd')
imp.addHdl(_ + './NES_2A03/Dan_2A03.vhd')
imp.addHdl(_ + './NES_2A03/T65_MCode.vhd')
imp.addHdl(_ + './NES_2A03/T65_Pack.vhd')
imp.addHdl(_ + './NES_2A03/ClockDivider.vhd')
imp.addHdl(_ + './NES_2A03/DanPack.vhd')

# NES APU

imp.addHdl(_ + 'myhdl/APU_Main.v')

# NES PPU

imp.addHdl(_ + './PPU/PPU.vhd')
imp.addHdl(_ + './PPU/TileFetcher.vhd')
imp.addHdl(_ + './PPU/PPU_Pack.vhd')
imp.addHdl(_ + './PPU/Loopy_Scrolling.vhd')
imp.addHdl(_ + './PPU/SpriteSelector.vhd')

# HDMI Output
imp.addHdl(_ + './HDMI/HDMIController.vhd')
imp.addHdl(_ + './HDMI/tft_interface.v')
imp.addHdl(_ + 'HDMI/HDMIController.vhd')
imp.addHdl(_ + 'HDMI/iic_init.v')
imp.addHdl(_ + './ColorPalette.vhd')

# AC97 Audio Output

imp.addHdl(_ + './ac97/ac97_top.vhd')
imp.addHdl(_ + './ac97/Talkthrough_Parts.vhd')

imp.createTcl(target = 'Generate Programming File')

# Run
imp.run()
