from myhdl import *


class CPU_Bus(object):
	def __init__(self, AddressWidth=16):
		self.CLK = Signal(False)
		self.RSTN = Signal(False)
		self.PHI2 = Signal(False)
		self.RW10 = Signal(True)

		self.Address = Signal(intbv()[AddressWidth:])
		self.Data_write = Signal(intbv()[8:])
		self.Data_read =	Signal(intbv()[8:])

		self.Data_slaves = []

		self.write_queue = []

		@always(self.CLK.posedge)
		def write_proc():
			if self.PHI2:
				if self.write_queue:
					a, d = self.write_queue.pop(0)
					self.Address.next = a
					self.Data_write.next = d
					self.RW10.next = 0
				else:
					self.RW10.next = 1

		self.instances = write_proc
			

	def RegisterSlaveAddress():
		assert False, "not implemented"


	def fake_write(self, address, data):
		self.write_queue += [(address, data)]

	

	
