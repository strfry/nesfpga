NESFPGA
=======

This project 

Getting Started
---------------

I used the Digilent Genesys FPGA board, which is currently the only board this
project works on.
Sadly, you will need a version of Xilinx ISE software to synthesize this project.
I used version 14.5, the free Webpack Edition should be fine.

Create a new project, and first include the top module Genesys_NES.vhd,
to see what other files are missing. Don't forget the constraints file nes_top.ucf.
Then add every .vhd and .v file, except the TestBenches, and CartridgeROM*.vhd

### Cartridge

CartridgeROM.vhd reads the ROM data from .dat files in the directory roms/.
The default filenames are 'roms/smb_chr.dat' and 'roms/smb_prg.dat'.
These files are already shipped with the project, but you can generate them
with tools/romconv.py. Beware, this project only supports 32 KiB ROMs.

XST should support the ROM inferrence style in CartridgeROM.vhd, but this is rather slow.
For faster synthesis, use CartridgeROM_Coregen.vhd and include
the appropriate .ngc files from the Coregen directory.
This directory also includes the Coregen project files, and romconv.py can be
modified to generate the necessary .coe files from .nes ROMs.


### MyHDL Part

Since the APU is programmed in MyHDL, it needs to be converted to VHDL or Verilog
code for synthesis. apu_convert.py does this for you, but you will need to install
MyHDL (at least version 0.7).
Alternatively, for synthesis you can just use the pregenerated file APU/APU_Main.v.


Directory Overview
------------------


NES_2A03        - The modified CPU from Dan Leach's NES-On-a-FPGA project
PPU             - Implementation of the NES 2C02
APU   	        - MyHDL code and testbench for the APU

TestBenches     - Various VHDL based testbenches
tools           - Tools for generating ROM helper files, and framebuffer viewer
roms            - ROM files in .nes and converted form

HDMI            - Chrontel CH7301C interface from xps_tft
ac97            - The 3rd party AC97 module with my wrapper

synaesthesia    - First attempt at a ISE-independent build system... Ignore for now


Flashing the FPGA board
-----------------------

To persistently save the bistream on the FPGA boards flash RAM, you
need to use Xilinx iMPact. These are the settings i used to generate
the MCS file:

- Parallel BPI Single Boot
- Virtex 5 / 32M
- 16 bit width
- 28F256P30 (not 512, the genesys schematic is lying)


Testbenches
-----------

### NES_Framebuffer_TB.vhd

This is the testbench for simulating everything down from NES_Mainboard.
But beware, you will need a fast and expensive simulator for this to be useful. 

It writes the framebuffer data to fbdump_top.out.
The FBView tool in tools/fbview can be used to view this file.
It includes a build script, but you will need a working gcc and the SDL
library to compile it.

The testbench also includes a primitive way for simulating controller pad inputs
in the process CONTROLLER_INPUT. It uses 1 for not pressed and 0 for pressed.
From left to right, the button mapping is "Right, Left, Down, Up, Start, Select, B, A"

### apu_tb.py

Unlike the other testbenches, this is found in the APU directory.
To use it, you will need Py65. Use these commands to get
and configure python to find it:

  $ cd APU
  $ git clone https://github.com/mnaberez/py65
  $ export PYTHONPATH=py65

To start simulating the first song of the SMB nsf, use this command:

  $ python apu_tb.py smb.nsf 0

It will write the file smb-0.wav to the output directory.

I recommend you to acquire a recent version of PyPy, and use it instead
of standard CPython, as it speeds up the simulation by orders of magnitude
