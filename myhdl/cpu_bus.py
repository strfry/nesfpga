from myhdl import *

class CPU_Bus(object):
	def __init__(self, AddressWidth=16):
		self.CLK = Signal(False)
		self.RSTN = Signal(False)
		self.PHI2 = Signal(False)
		self.RW10 = Signal(True)

		self.Address = Signal(intbv()[AddressWidth])
		self.Data_out = Signal(intbv()[8])
		self.Data_in =	Signal(intbv()[8])

		self.Data_slaves = []
		print instances()
		self.instances = instances()

	def RegisterSlaveAddress():
		assert False, "not implemented"

	def instances():
		return self.instances

	

	
