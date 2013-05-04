# This script generates a video overlay that can draw signal waveforms and arbitrary text on the screen. I fucking hate Xilinx ChipScope

from myhdl import *

def DebugOverlay(InputPixel, DebugPixel, ...)
	"""This module can be inserted into 

def convert()
	input = Signal(intbv([6:0]))
	output = Signal(intbv([6:0]))
	toVHDL(DebugOverlay, input, output, 
