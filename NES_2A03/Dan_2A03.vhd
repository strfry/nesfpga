--Dan Leach
--2A03 for NES
--Created 1/03/06
	--Initial revision
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Pack_2A03.all;

entity NES_2A03 is
	port (
		Global_Clk	: in std_logic;		--input clock signal from NES mobo crystal
		Reset_N 		: in std_logic;		--External Reset
		NMI_N 		: in std_logic;
		IRQ_N 		: in std_logic;
		Data 			: inout std_logic_vector(7 downto 0);
		Address 		: buffer std_logic_vector(15 downto 0);
		RW_10			: buffer std_logic;		--low if writing, high if reading
		PHI1			: out std_logic;
		PHI2 			: out std_logic;	--Clock Divider Output
		
		--Controller Outputs
		CStrobe	: out std_logic;	--Controller Strobe Signal 
		C1R_N 	: out std_logic;	--low when reading controller 1
		C2R_N 	: out std_logic;	--low when reading controller 2
		
		--Audio Outputs
		A_Rectangle : out std_logic;	--Rectangle Wave Output (Mixed)
		A_Combined 	: out std_logic;	--Triangle, Noise, And PCM (DPCM) Output
		
		--The following three signals represent the status of an internal register
		--	used in accessing the expansion port
		W_4016_1 	: out std_logic;
		W_4016_2 	: out std_logic;
		
		--Debugging
		ClockDividerTrigger : out std_logic;
		--LCycle : out std_logic_vector(2 downto 0);
		--MCycle : out std_logic_vector(2 downto 0);
		--InitialReset : out std_logic;
		AddOKDebug : out std_logic;
		ReadOKDebug : out std_logic;
		WriteOKDebug : out std_logic;
		SRAMChipSelect_NDebug : out std_logic;
		SRAMWriteEnable_NDebug : out std_logic;
		SRAMOutputEnable_NDebug :out std_logic;
		SRAMReading : out std_logic;
		SRAMWriting : out std_logic
	);
end NES_2A03;

architecture Behavioral of NES_2A03 is
	--Clock Control
	signal PHI1_Internal	: std_logic;
	signal PHI2_Internal	: std_logic;
	
	--Internal Status Registers
	signal Global_Enable	: std_logic;
	
	--T65 Control
	signal	T65Enable 	: std_logic;
	signal	T65RW_10 	: std_logic := '0';
	signal	T65Address	: std_logic_vector (15 downto 0);
	signal	T65DataIn	: std_logic_vector(7 downto 0);
	signal	T65DataOut	: std_logic_vector(7 downto 0);
	
	--DMA
	signal	TransferCount		: unsigned (9 downto 0);
	signal	TransferAddress	: unsigned (15 downto 0);
	signal	DMAEnable	: std_logic;
	signal	DMARW_10 	: std_logic := '0';
	signal	DMAAddress	: std_logic_vector (15 downto 0) := "0000000000000000";
	signal	DMADataIn 	: std_logic_vector(7 downto 0);
	signal	DMADataOut	: std_logic_vector(7 downto 0);
	signal	DMAContinue : std_logic;
	signal	DMADelay 	: unsigned (2 downto 0);
	
	--Bus Control
	signal	BusControl		: std_logic;
	signal	RW_10Signal		: std_logic;
	signal	AddressSignal	: std_logic_vector (15 downto 0);
	signal	DataInSignal	: std_logic_vector (7 downto 0);
	signal	DataOutSignal	: std_logic_vector (7 downto 0);
	
	--Bus Timing
	signal	AddOKSignal		: std_logic := '0';
	signal	ReadOKSignal	: std_logic := '0';
	signal	WriteOKSignal	: std_logic := '0';
	
	--Memory
	signal	SRAMWriteSignal	: std_logic;
	signal	SRAM_Reading		: std_logic;
	signal	SRAM_Writing		: std_logic;
	
	--Controllers
	signal	ControllerOnePoll : std_logic := '0';
	signal	ControllerTwoPoll : std_logic := '0';
	
begin
--more or less constant assignments
	Global_Enable	<=	'1';
	PHI1	<= PHI1_Internal;
	PHI2	<= PHI2_Internal;
	
	SRAMWriteSignal <= not ReadOKSignal when RW_10 = '0' else '1';
	
--to be implemented later
	A_Rectangle <= '0';
	A_Combined 	<= '0';
	W_4016_1		<= 'Z';
	W_4016_2		<= 'Z';

--Debugging
	WriteOKDebug	<= WriteOKSignal;
	AddOKDebug		<= AddOKSignal;
	ReadOKDebug		<= ReadOKSignal;
	
	SRAMWriteEnable_NDebug <= SRAMWriteSignal;
	SRAMOutputEnable_NDebug <= '0';
	SRAMChipSelect_NDebug <= (not PHI2_Internal) or (Address(15) or Address(14) or Address(13));
	
	SRAMReading <= SRAM_Reading;
	SRAMWriting <= SRAM_Writing;

--Controllers
ControllerOnePoll <= '1' when Address = x"4016" else '0';
ControllerTwoPoll <= '1' when Address = x"4017" else '0';
C1R_N <= not (ControllerOnePoll and RW_10 and PHI2_Internal);
C2R_N <= not (ControllerTwoPoll and RW_10 and PHI2_Internal);

process (Address, ReadOKSignal, RW_10, PHI2_Internal)
begin
	if (Address = x"4016" and RW_10 = '0' and ReadOKSignal = '1') then
		Data <= "ZZZZZZZZ";
		CStrobe <= Data(0);
	elsif (Address = x"4016" and RW_10 = '1' and PHI2_Internal = '1') then
		Data <= "010ZZZZZ";
	else
		Data <= "ZZZZZZZZ";
	end if;
end process;

--Bus Control
with BusControl select RW_10Signal <=
	T65RW_10 when '0',
	DMARW_10	when '1';
			
with BusControl select AddressSignal <=
	T65Address when '0',
	DMAAddress when '1';
	
T65DataIn	<= DataInSignal when BusControl = '0' else "01010101"; --????
DMADataIn	<= DataInSignal when BusControl = '1' else "01010101";
	
with BusControl select DataOutSignal <=
	T65DataOut when '0',
	DMADataOut when '1';

--Bus stuff
process (Reset_N, AddOKSignal)
begin
	if (Reset_N = '0') then
		DMAEnable <= '0';
		Address <= x"0000";
	else
		if AddOKSignal'event and AddOKSignal = '1' then
			RW_10 <= RW_10Signal;
			Address <= AddressSignal;
			if (T65Address = x"4014") then
				DMAEnable	<= '1';
			else
				DMAEnable	<= '0';		
			end if;
		end if;
	end if;
end process;

process (RW_10Signal, ReadOKSignal, WriteOKSignal, PHI2_Internal)
begin
	if (RW_10Signal = '1') then --reading
		if (PHI2_Internal = '0') then
			Data <= DataInSignal; --might be causing big-ass problems
		else
			Data <= "ZZZZZZZZ";
			if (ReadOKSignal = '1') then
				DataInSignal <= Data;
			end if;
		end if;
	else --writing
		if (PHI2_Internal = '1' and WriteOKSignal = '1') then
			Data		<= DataOutSignal;
			DataInSignal	<= Data;
		else
			--Data 		<= DataInSignal;
		end if;
	end if;
end process;

DMATransfer : process (Reset_N, PHI2_Internal)
begin
	if (Reset_N = '0') then
		TransferCount		<= "0000000000";
		TransferAddress	<= "0000000000000000";
		DMAContinue <= '0';
		T65Enable <= '1';
		BusControl <= '0';
		DMARW_10 <= '1';
		--D
	elsif (falling_edge(PHI2_Internal)) then  --may need to check timing here
		if (DMAEnable = '1') then
			DMAContinue <= '1';
		end if;
		if (DMAContinue = '1') then
			case TransferCount is
				when "0000000000" =>
					DMAAddress	<= T65DataOut & "00000000";
					TransferAddress <= unsigned(T65DataOut & "00000000") + 1;
					T65Enable <= '0';
					BusControl <= '1';
					TransferCount <= "0000000001";
				when "1000000000" =>
					T65Enable <= '1';
					BusControl <= '0';
					TransferCount <= "0000000000";
					DMAContinue <= '0';
					DMARW_10 <= '1'; --shit dude, it's amazing anything happened without this
				when others =>
					T65Enable <= '0';
					BusControl <= '1';
					TransferCount <= TransferCount + 1;
					case TransferCount(0) is
						when '0' =>
							DMARW_10 <= '1';
							DMAAddress <=  std_logic_vector(TransferAddress);
							TransferAddress <= TransferAddress + 1;
						when '1' =>
							DMARW_10 <= '0';
							DMAAddress <=  x"2004";
							DMADataOut <= DMADataIn;
					end case;
			end case;
		end if;
	end if;
end process DMATransfer;

--Port Maps	
	Clk_Div_12 : Clock_Divider
		port map (
			Clk_In				=> Global_Clk,
			Reset_N				=> Reset_N,
			Enable				=> Global_Enable,
			Clk_Out				=> PHI1_Internal,
			Clk_Out_Phi2		=> PHI2_Internal,
			Clk_Out_AddOK 		=> AddOKSignal,
			Clk_Out_WriteOK	=> WriteOKSignal,
			Clk_Out_ReadOK		=> ReadOKSignal,
			In_Out	 			=> ClockDividerTrigger
		);
	
	NES_2A03 : T65
		port map (
			Mode			=> "00",
			Res_n			=> Reset_N,
			Enable		=> T65Enable,
			Clk			=> PHI1_Internal,
			Clk_Phi2		=> PHI2_Internal,
			Clk_AddOK 	=> AddOKSignal,
			Clk_ReadOK 	=> ReadOKSignal,
			Rdy     		=> '1',	--used for single-cycle execution, not used in 2A03
			--Abort_n		=> '0',	--not used at all
			IRQ_n   		=> IRQ_N,
			NMI_n   		=> NMI_N,
			SO_n    		=> '1',	--Set Overflow, not used by NES
			R_W_n   		=> T65RW_10,
			Sync    		=> open,	--used for single-cycle execution, not used in 2A03
			ML_n    		=> open,	--used in 65C816
			VP_n    		=> open,	--used in 65C816
			VDA     		=> open,	--used in 65C816
			VPA     		=> open,	--used in 65C816
			T65Address	=> T65Address,
			T65DataIn	=> T65DataIn,
			T65DataOut	=> T65DataOut
		);
		
	CPU_RAM : SRAM
		port map (
			--Clock				=> PHI2_Internal,
			ChipSelect_N	=> (not PHI2_Internal) or (Address(15) or Address(14) or Address(13)),
			ReadEnable_N	=> not RW_10,
			WriteEnable_N	=> SRAMWriteSignal,
			OutputEnable_N	=> '0',--not WriteOKSignal,--< this is a problem :-(
			Address			=> Address (10 downto 0),
			Data				=> Data,
			Reading			=> SRAM_Reading,
			Writing			=> SRAM_Writing
		);
end;