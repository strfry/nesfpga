from myhdl import *

NES_CLK_period = 46 * 12
#  constant AC97_CLK_period : time := 20.833333333333332 us; -- 48 kHz
#  constant CLK_period : time := 46.560848137510206 ns; -- 21.477272 MhZ


def APU_Main(
		CLK,
		PHI1_CE,
		PHI2_CE,
		RW10,

		Address,
		Data_read,
		Data_write,

		Interrupt,
		PCM_out
		):

	APU_CE = Signal(False)
	APU_CE_cnt = Signal(False)

	Pulse1_CS = Signal(False)

	pulse1 = APU_Pulse(CLK, APU_CE, RW10, Address, Data_write, Pulse1_CS, PCM_out)

	@always(CLK.posedge)
	def ce():
		if PHI1_CE:
			APU_CE_cnt.next = not APU_CE_cnt

	@always_comb
	def chipselect():
		Pulse1_CS.next = 0x4000 <= Address and Address < 0x4004
		APU_CE.next = PHI1_CE and APU_CE_cnt

	return instances()

	

def APU_FrameCounter(
		CLK,
		APU_CE,

		Mode,
		InterruptInhibit,

		QuarterFrameOut,
		HalfFrameOut,
		InterruptFlagOut
		):

	timer = Signal(intbv())

	@always(CLK.posedge)
	def logic():
		QuarterFrameOut.next = False
		HalfFrameOut.next = False

		if APU_CE:
			timer.next = timer + 1

			if timer == 3728:
				QuarterFrameOut.next = True
			elif timer == 7456:
				HalfFrameOut.next = True
				QuarterFrameOut.next = True
			elif timer == 11186:
				QuarterFrameOut.next = True
			elif not Mode and timer == 14914:
				HalfFrameOut.next = True
				QuarterFrameOut.next = True
				timer.next = 0
			elif Mode and timer == 18640:
				HalfFrameOut.next = True
				QuarterFrameOut.next = True
				timer.next = 0

	return logic


def APU_Envelope(
		CLK,
		HalfFrame_CE,

		StartFlag,
		LoopFlag,
		ConstantFlag,
		
		LengthCounterLoad,
		VolumeDecay,

		VolumeOut
		):

	timer = Signal(intbv()[4:0])

	@always(CLK.posedge)
	def logic():
		if HalfFrame_CE:
			if StartFlag:
				print "Start Envelope"
				StartFlag.next = False
				VolumeOut.next = 15
				timer.next = VolumeDecay
			else:
				if timer == 0:
					timer.next = VolumeDecay
					if VolumeOut != 0:
						VolumeOut.next = VolumeOut - 1
					else:
						if LoopFlag:
							VolumeOut.next = 15						
				else:
					timer.next = timer - 1

	return logic



def APU_Pulse(
	CLK, APU_CE, RW10, Address, Data_write,
	ChipSelect,
	PCM_out):

	DutyCycle = Signal(intbv()[2:0])
	LengthCounterHalt = Signal(False)
	Envelope = Signal(intbv()[5:0])

	TimerLoad = Signal(intbv()[11:0])

	sequencer = Signal(intbv("00001111"))
	timer = Signal(intbv()[11:0])

	@always(CLK.posedge)
	def logic():
		if APU_CE and RW10 == 0 and ChipSelect:
			if Address[2:0] == 0x0:
				DutyCycle.next = Data_write[8:6]
				LengthCounterHalt.next = Data_write[6]
				Envelope.next = Data_write[5:0]
			elif Address[2:0] == 0x1:
				# Sweep unit unimplemented
				pass
			elif Address[2:0] == 0x2:
				TimerLoad.next[8:0] = Data_write
				print "new pulse timer period: ", TimerLoad.next
			elif Address[2:0] == 0x3:
				TimerLoad.next[11:8] = Data_write[3:0]
				print "new pulse timer period: ", TimerLoad.next
		if APU_CE:
			if timer == 0:
				sequencer.next = concat(sequencer[0], sequencer[8:1])
				PCM_out.next = 0xf if sequencer[0] else 0x00
				#print sequencer
				timer.next = TimerLoad
			else:
				timer.next = timer - 1
	return instances()


def APU_Triangle(
		CLK,
		APU_CE,

		TimerLoad,

		PCM_OUT
		):
	
	lut = [15, 14, 13, 12, 11, 10,  9,  8,  7,  6,  5,  4,  3,  2,  1,  0, 0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15]
	sequencer = Signal(0)
	timer = Signal(intbv(0))

	@always(CLK.posedge)
	def logic():
		if APU_CE:
			if timer == 0:
				sequencer.next = (sequencer + 1) % 32
				PCM_OUT.next = lut[sequencer]
				#timer.next = TimerLoad
				timer.next = 0x0fd
			else:
				timer.next = timer - 1

	return logic

def APU_Noise(
		CLK,
		APU_CE,

		EnvelopeIn,

		TimerPeriod,
		Mode,


		PCM_OUT
		):

	lut = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]
	lfsr = Signal(intbv("111111111111111")[15:0])
	timer = Signal(intbv())

	@always(CLK.posedge)
	def logic():
		if timer == 0:
			fb_bit = lfsr[0] ^ (lfsr[6] if Mode else lfsr[1])
			lfsr.next = concat(fb_bit, lfsr[15:1])
			PCM_OUT.next = EnvelopeIn if lfsr[0] else 0x00
			timer.next = lut[TimerPeriod]
		else:
			timer.next = timer - 1

	return logic

