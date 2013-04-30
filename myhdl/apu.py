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
	Pulse2_CS = Signal(False)
	Noise_CS = Signal(False)

	HalfFrame_CE = Signal(False)
	QuarterFrame_CE = Signal(False)

	PCM_pulse1 = Signal(intbv())
	PCM_pulse2 = Signal(intbv())
	PCM_noise = Signal(intbv())

	frameCounter = APU_FrameCounter(CLK, APU_CE, RW10, Address, Data_write, HalfFrame_CE, QuarterFrame_CE, Interrupt)
	pulse1 = APU_Pulse(CLK, APU_CE, RW10, Address, Data_write, Pulse1_CS, HalfFrame_CE, QuarterFrame_CE, PCM_pulse1)
	pulse2 = APU_Pulse(CLK, APU_CE, RW10, Address, Data_write, Pulse2_CS, HalfFrame_CE, QuarterFrame_CE, PCM_pulse2)
	noise = APU_Noise(CLK, APU_CE, RW10, Address, Data_write, Noise_CS, HalfFrame_CE, QuarterFrame_CE, PCM_noise)

	@always(CLK.posedge)
	def ce():
		if PHI1_CE:
			APU_CE_cnt.next = not APU_CE_cnt

	@always_comb
	def chipselect():
		Pulse1_CS.next = 0x4000 <= Address and Address < 0x4004
		Pulse2_CS.next = 0x4004 <= Address and Address < 0x4008
		Noise_CS.next = 0x400C <= Address and Address < 0x4010
		APU_CE.next = PHI1_CE and APU_CE_cnt

		PCM_out.next = PCM_pulse1 + PCM_pulse2 + PCM_noise

	return instances()

	

def APU_FrameCounter(
	CLK, APU_CE, RW10, Address, Data_write,
	HalfFrame_CE, QuarterFrame_CE, Interrupt):

	timer = Signal(intbv())
	Mode = Signal(False)
	InterruptInhibit = Signal(False)

	@always(CLK.posedge)
	def logic():
		if APU_CE and not RW10 and Address == 0x4017:
			Mode.next = Data_write[7]
			InterruptInhibit.next = Data_write[6]

		QuarterFrame_CE.next = False
		HalfFrame_CE.next = False

		if APU_CE:
			timer.next = timer + 1

			if timer == 3728:
				QuarterFrame_CE.next = True
			elif timer == 7456:
				HalfFrame_CE.next = True
				QuarterFrame_CE.next = True
			elif timer == 11186:
				QuarterFrame_CE.next = True
			elif not Mode and timer == 14914:
				HalfFrame_CE.next = True
				QuarterFrame_CE.next = True
				timer.next = 0
			elif Mode and timer == 18640:
				HalfFrame_CE.next = True
				QuarterFrame_CE.next = True
				timer.next = 0

	return instances()


def APU_Envelope(
		CLK,
		QuarterFrame_CE,

		StartFlag,
		LoopFlag,
		ConstantFlag,
		
		VolumeDecay,

		VolumeOut
		):

	divider = Signal(intbv()[4:0])
	volume = Signal(intbv()[4:0])

	@always(CLK.posedge)
	def logic():
		if QuarterFrame_CE:
			if StartFlag:
				print "Start Envelope, length: ", VolumeDecay, " constant: ", ConstantFlag
				StartFlag.next = False
				volume.next = 15
				divider.next = VolumeDecay
			else:
				if divider == 0:
					divider.next = VolumeDecay
					if volume != 0:
						volume.next = volume - 1
					else:
						if LoopFlag:
							volume.next = 15						
				else:
					divider.next = divider - 1

	@always_comb
	def comb():
		if ConstantFlag:
			VolumeOut.next = VolumeDecay
		else:
			VolumeOut.next = volume
				

	return instances()

def LengthCounter(
	CLK, APU_CE, RW10, Address, Data_write,
	ChipSelect, HalfFrame_CE, Enable_out
	):

	LengthCounter = Signal(intbv()[8:0])
	LengthCounterHalt = Signal(False)

	# Lookup Table for Length Counter values
	LC_lut = [
		10, 254, 20,  2, 40,  4, 80,  6,
		160,  8, 60, 10, 14, 12, 26, 14,
		12, 16, 24, 18, 48, 20, 96, 22,
		192, 24, 72, 26, 16, 28, 32, 30
	]

	@always(CLK.posedge)
	def logic():
		if APU_CE and RW10 == 0 and ChipSelect:
			if Address[2:0] == 0x0:
				LengthCounterHalt.next = Data_write[5]
			elif Address[2:0] == 0x3:
				print "xOxOx Length Counter write ", Data_write[8:3], "/", LC_lut[Data_write[8:3]]
				LengthCounter.next = LC_lut[Data_write[8:3]]
		
		if HalfFrame_CE:
			print LengthCounter
			if LengthCounter and not LengthCounterHalt:
				LengthCounter.next = LengthCounter - 1

	@always_comb
	def comb():
		Enable_out.next = LengthCounter > 0

	return instances()

def APU_Pulse(
	CLK, APU_CE, RW10, Address, Data_write,
	ChipSelect, HalfFrame_CE, QuarterFrame_CE,
	PCM_out):

	lengthCounterEnable = Signal(False)

	lengthCounter = LengthCounter(CLK, APU_CE, RW10, Address, Data_write, ChipSelect, HalfFrame_CE, lengthCounterEnable)

	DutyCycle = Signal(intbv()[2:0])

	EnvelopeDecay = Signal(intbv()[4:0])
	EnvelopeConstantFlag = Signal(False)
	EnvelopeStartFlag = Signal(False)
	EnvelopeVolume = Signal(intbv()[4:0])

	envelope = APU_Envelope(CLK, QuarterFrame_CE,
		EnvelopeStartFlag, Signal(False), EnvelopeConstantFlag,
                EnvelopeDecay, EnvelopeVolume)	

	TimerLoad = Signal(intbv()[11:0])

	sequencer = Signal(intbv("00001111"))
	timer = Signal(intbv()[11:0])

	@always(CLK.posedge)
	def logic():
		if APU_CE and RW10 == 0 and ChipSelect:
			if Address[2:0] == 0x0:
				DutyCycle.next = Data_write[8:6]
				EnvelopeConstantFlag.next = Data_write[4]
				EnvelopeDecay.next = Data_write[4:0]
			elif Address[2:0] == 0x1:
				# Sweep unit unimplemented
				pass
			elif Address[2:0] == 0x2:
				TimerLoad.next[8:0] = Data_write
				print "new pulse timer period: ", TimerLoad.next
			elif Address[2:0] == 0x3:
				EnvelopeStartFlag.next = True
				TimerLoad.next[11:8] = Data_write[3:0]
				print "new pulse timer period: ", TimerLoad.next
		if APU_CE:
			if timer == 0:
				sequencer.next = concat(sequencer[0], sequencer[8:1])
				PCM_out.next = EnvelopeVolume if sequencer[0] else 0x00
				if not lengthCounterEnable:
					PCM_out.next = 0
				#print sequencer
				timer.next = TimerLoad
			else:
				timer.next = timer - 1
	return instances()

def LengthCounter2(
	CLK, HalfFrame_CE,
	LengthCounterHalt, LengthCounterLoad, LengthCounterLoadFlag,
	Enable_out
	):

	LengthCounter = Signal(intbv()[8:0])

	# Lookup Table for Length Counter values
	LC_lut = [
		10, 254, 20,  2, 40,  4, 80,  6,
		160,  8, 60, 10, 14, 12, 26, 14,
		12, 16, 24, 18, 48, 20, 96, 22,
		192, 24, 72, 26, 16, 28, 32, 30
	]

	@always(CLK.posedge)
	def logic():
		if HalfFrame_CE:
			if LengthCounter and not LengthCounterHalt:
				print LengthCounter
				LengthCounter.next = LengthCounter - 1
		
		if LengthCounterLoadFlag:
			LengthCounter.next = LC_lut[LengthCounterLoad]

	@always_comb
	def comb():
		Enable_out.next = LengthCounter > 0

	return instances()

def APU_Noise(
	CLK, APU_CE, RW10, Address, Data_write,
	ChipSelect, HalfFrame_CE, QuarterFrame_CE,
	PCM_out):

	lut = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]
	lfsr = Signal(intbv("111111111111111")[15:0])
	timer = Signal(intbv())

	TimerLoad = Signal(intbv())
	LFSRMode = Signal(False)

	LengthCounterHalt = Signal(False)
	LengthCounterLoadFlag = Signal(False)
	LengthCounterLoad = Signal(intbv())

	lengthCounterEnable = Signal(False)

	DutyCycle = Signal(intbv()[2:0])

	EnvelopeDecay = Signal(intbv()[4:0])
	EnvelopeConstantFlag = Signal(False)
	EnvelopeStartFlag = Signal(False)
	EnvelopeVolume = Signal(intbv()[4:0])

	lengthCounter = LengthCounter2(CLK, HalfFrame_CE, LengthCounterHalt, LengthCounterLoad, LengthCounterLoadFlag, lengthCounterEnable)
	envelope = APU_Envelope(CLK, QuarterFrame_CE, EnvelopeStartFlag, Signal(False), EnvelopeConstantFlag,
                EnvelopeDecay, EnvelopeVolume)	


	@always(CLK.posedge)
	def logic():
		LengthCounterLoadFlag.next = False
		if APU_CE and RW10 == 0 and ChipSelect:
			if Address[2:0] == 0x0:
				LengthCounterHalt.next = Data_write[5]
				EnvelopeConstantFlag.next = Data_write[4]
				EnvelopeDecay.next = Data_write[4:0]
				print "Noise Envelope config: Constant:", EnvelopeConstantFlag.next, "Decay: ", EnvelopeDecay.next
			elif Address[2:0] == 0x2:
				LFSRMode.next = Data_write[7]
				TimerLoad.next[4:0] = Data_write[4:0]
			elif Address[2:0] == 0x3:
				EnvelopeStartFlag.next = True
				LengthCounterLoad.next = Data_write[8:3]
				LengthCounterLoadFlag.next = True
		if APU_CE:
			if timer == 0:
				fb_bit = lfsr[0] ^ (lfsr[6] if LFSRMode else lfsr[1])
				lfsr.next = concat(fb_bit, lfsr[15:1])
				PCM_out.next = EnvelopeVolume if lfsr[0] and lengthCounterEnable else 0x00
				timer.next = lut[TimerLoad]
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
	return instances()
