--//////////Package file for AC97 Talkthrough //////////////////////////--
-- ***********************************************************************
-- FileName: Talkthrough_Parts.vhd
-- FPGA: Xilinx Spartan 6
-- IDE: Xilinx ISE 13.1 
--
-- HDL IS PROVIDED "AS IS." DIGI-KEY EXPRESSLY DISCLAIMS ANY
-- WARRANTY OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING BUT NOT
-- LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
-- PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL DIGI-KEY
-- BE LIABLE FOR ANY INCIDENTAL, SPECIAL, INDIRECT OR CONSEQUENTIAL
-- DAMAGES, LOST PROFITS OR LOST DATA, HARM TO YOUR EQUIPMENT, COST OF
-- PROCUREMENT OF SUBSTITUTE GOODS, TECHNOLOGY OR SERVICES, ANY CLAIMS
-- BY THIRD PARTIES (INCLUDING BUT NOT LIMITED TO ANY DEFENSE THEREOF),
-- ANY CLAIMS FOR INDEMNITY OR CONTRIBUTION, OR OTHER SIMILAR COSTS.
-- DIGI-KEY ALSO DISCLAIMS ANY LIABILITY FOR PATENT OR COPYRIGHT
-- INFRINGEMENT.
--
-- Version History
-- Version 1.0 12/06/2011 Tony Storey
-- Initial Public Release


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;



package Spar6_Parts is







--/////////////////////// AC97 Driver //////////////////////////////////--



component ac97 
	port (
		n_reset        : in  std_logic;
		clk            : in  std_logic;
																				-- ac97 interface signals
		ac97_sdata_out : out std_logic;								-- ac97 output to SDATA_IN
		ac97_sdata_in  : in  std_logic;								-- ac97 input from SDATA_OUT
		ac97_sync      : out std_logic;								-- SYNC signal to ac97
		ac97_bitclk    : in  std_logic;								-- 12.288 MHz clock from ac97
		ac97_n_reset   : out std_logic;								-- ac97 reset for initialization [active low]
		ac97_ready_sig : out std_logic; 								-- pulse for one cycle
		L_out          : in  std_logic_vector(17 downto 0);	-- lt chan output from ADC
		R_out          : in  std_logic_vector(17 downto 0);	-- rt chan output from ADC
		L_in           : out std_logic_vector(17 downto 0);	-- lt chan input to DAC
		R_in           : out std_logic_vector(17 downto 0);	-- rt chan input to DAC
		latching_cmd	: in std_logic;
		cmd_addr       : in  std_logic_vector(7 downto 0);		-- cmd address coming in from ac97cmd state machine
		cmd_data       : in  std_logic_vector(15 downto 0) 	-- cmd data coming in from ac97cmd state machine
		);
end component;


--/////////////// STATE MACHINE TO CONFIGURE THE AC97 ///////////////////////////--

component ac97cmd 
	port (
		 clk      		: in  std_logic;
		 ready    		: in  std_logic;
		 cmd_addr 		: out std_logic_vector(7 downto 0);
		 cmd_data 		: out std_logic_vector(15 downto 0);
		 latching_cmd 	: out std_logic;
		 volume   		: in  std_logic_vector(4 downto 0);
		 source   		: in  std_logic_vector(2 downto 0)
		 );
end component;
  







end Spar6_Parts;




-------------------------------------------------------------------------------------
--//////////////////////////// COMPONENTS /////////////////////////////////////////--
-------------------------------------------------------------------------------------



--/////////////////////// AC97 CONTROLLER //////////////////////////////////--




library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity ac97 is
	port (
		n_reset        : in  std_logic;
		clk            : in  std_logic;
																				-- ac97 interface signals
		ac97_sdata_out : out std_logic;								-- ac97 output to SDATA_IN
		ac97_sdata_in  : in  std_logic;								-- ac97 input from SDATA_OUT
		ac97_sync      : out std_logic;								-- SYNC signal to ac97
		ac97_bitclk    : in  std_logic;								-- 12.288 MHz clock from ac97
		ac97_n_reset   : out std_logic;								-- ac97 reset for initialization [active low]
		ac97_ready_sig : out std_logic; 								-- pulse for one cycle
		L_out          : in  std_logic_vector(17 downto 0);	-- lt chan output from ADC
		R_out          : in  std_logic_vector(17 downto 0);	-- rt chan output from ADC
		L_in           : out std_logic_vector(17 downto 0);	-- lt chan input to DAC
		R_in           : out std_logic_vector(17 downto 0);	-- rt chan input to DAC
		latching_cmd	: in std_logic;
		cmd_addr       : in  std_logic_vector(7 downto 0);		-- cmd address coming in from ac97cmd state machine
		cmd_data       : in  std_logic_vector(15 downto 0));	-- cmd data coming in from ac97cmd state machine
end ac97;


architecture arch of ac97 is


	signal Q1, Q2   			: std_logic;								-- signals to deliver one cycle pulse at specified time
	signal bit_count    		: std_logic_vector(7 downto 0);		-- counter for aligning slots
	signal rst_counter  	 	: integer range 0 to 4097;				-- counter to set ac97_reset high for ac97 init
								
	signal latch_cmd_addr   : std_logic_vector(19 downto 0);		-- signals to latch in registers and commands
	signal latch_cmd_data   : std_logic_vector(19 downto 0);

	signal latch_left_data	: std_logic_vector(19 downto 0);
	signal latch_right_data : std_logic_vector(19 downto 0);

	signal left_data     	: std_logic_vector(19 downto 0);
	signal right_data    	: std_logic_vector(19 downto 0);
	signal left_in_data  	: std_logic_vector(19 downto 0);
	signal right_in_data 	: std_logic_vector(19 downto 0);
	
  
begin

	-- concat for 18 bit usage can concat further for 16 bit use 
	-- by using <& "0000"> and <left_in_data(19 downto 4)>
	-------------------------------------------------------------------------------------
	left_data  <= L_out & "00";
	right_data <= R_out & "00";

	L_in <= left_in_data(19 downto 2);
	R_in <= right_in_data(19 downto 2);
	

	-- Delay for ac97_reset signal, clk = 100MHz
	-- delay 10ns * 37.89 us for active low reset on init
	--------------------------------------------------------------------------------------
	process (clk, n_reset)
	begin
		if (clk'event and clk = '1') then
			if n_reset = '0' then
				rst_counter <= 0;
				ac97_n_reset <= '0';
			elsif rst_counter = 3789 then  
				ac97_n_reset <= '1';
				rst_counter <= 0;
			else
				rst_counter <= rst_counter + 1;
			end if;
		end if;
	end process;
	
	
	-- This process generates a single clkcycle pulse
	-- to get configuration data from the ac97cmd FSM
	-- and lets the user know when a sample is ready
	---------------------------------------------------------------------------------------										
	process (clk, n_reset, bit_count)
	begin
		if(clk'event and clk = '1') then
			Q2 <= Q1;
			if(bit_count = "00000000") then
				Q1 <= '0';
				Q2 <= '0';
			elsif(bit_count >= "10000001") then
				Q1 <= '1';
			end if;
			ac97_ready_sig <= Q1 and not Q2;
		end if;
	end process;
		
		
	-- ac97-link frame is 256 cycles 
	-- [slot0], [slot1], [slot2], [slot3], [slot4], [slot5] ... [slot9], [slot10], [slot11], [slot12]
	-- slot 0 [tag phase] is 16 cycles slot1:12 are 20 cycles so 16 + 12 * 20 = 256 cycles
	-- ac97 link output frame [frame going out]
	---------------------------------------------------------------------------------------
	process (n_reset, bit_count, ac97_bitclk)
	begin
	 
		if(n_reset = '0') then																-- active low reset
			bit_count <= "00000000";														-- starts bit count at 0
		elsif (ac97_bitclk'event and ac97_bitclk = '1') then							-- rising edge of ac97_bitclk
		
			if bit_count = "11111111" then												-- Generate sync signal for ac97
				ac97_sync <= '1';																-- at bitcnt = 255

			end if;

			if bit_count = "00001111" then												-- at bitcnt = 15
				ac97_sync <= '0';
			end if;


																									-- At the end of each frame the user data is latched in 
			if bit_count = "11111111" then
				latch_cmd_addr   <= cmd_addr & "000000000000";
				latch_cmd_data   <= cmd_data & "0000";
				latch_left_data  <= left_data;
				latch_right_data <= right_data;
			end if;
																									-- Tag phase
			if (bit_count >= "00000000") and (bit_count <= "00001111") then	-- bit count 0 to 15
																									-- Slot 0 : Tag Phase
				case bit_count is																-- Can create input signals to verify on tag phase
					when "00000000"      => ac97_sdata_out <= '1';      			-- AC Link Interface ready
					when "00000001"      => ac97_sdata_out <= latching_cmd;  	-- Vaild Status Adress or Slot request
					when "00000010"      => ac97_sdata_out <= '1';  				-- Valid Status data 
					when "00000011"      => ac97_sdata_out <= '1';      			-- Valid PCM Data (Left ADC)
					when "00000100"      => ac97_sdata_out <= '1';      			-- Valid PCM Data (Right ADC)
					when others => ac97_sdata_out <= '0';
				end case;
																										-- starting at slot 1 add 20 bit counts each time
			elsif (bit_count >= "00010000") and (bit_count <= "00100011") then	-- bit count 16 to 35
																										-- Slot 1 : Command address (8-bits, left justified)
																						
				if latching_cmd = '1' then
					ac97_sdata_out <= latch_cmd_addr(35 - to_integer(unsigned(bit_count)));
				else
					ac97_sdata_out <= '0';
				end if;

				elsif (bit_count >= "00100100") and (bit_count <= "00110111") then	-- bit count 36 to 55
																											-- Slot 2 : Command data (16-bits, left justified)
																						
				if latching_cmd = '1' then
					ac97_sdata_out <= latch_cmd_data(55 - to_integer(unsigned(bit_count)));
				else
					ac97_sdata_out <= '0';
				end if;

			elsif ((bit_count >= "00111000") and (bit_count <= "01001011")) then	-- bit count 56 to 75

																										-- Slot 3 : left channel
																						
				ac97_sdata_out <= latch_left_data(19);										-- send out bits and rotate through 20 bit word

				latch_left_data <= latch_left_data(18 downto 0) & latch_left_data(19);

			elsif ((bit_count >= "01001100") and (bit_count <= "01011111")) then	-- bit count 76 to 95
																										-- Slot 4 : right channel
																						
				ac97_sdata_out <= latch_right_data(95 - to_integer(unsigned(bit_count)));
		  
			else
				ac97_sdata_out <= '0';
			end if;

																										-- incriment bit counter
			bit_count <= std_logic_vector(unsigned(bit_count) + 1);
		end if;
	end process;

	-- ac97 link input frame [frame coming in]
	---------------------------------------------------------------------------
	process (ac97_bitclk)
	begin
		if (ac97_bitclk'event and ac97_bitclk = '0') then								-- clock on falling edge of bitclk
			if (bit_count >= "00111001") and (bit_count <= "01001100") then 		-- from 115 to 76
																										-- Slot 3 : left channel
				left_in_data <= left_in_data(18 downto 0) & ac97_sdata_in;			-- concat incoming bits on end
			elsif (bit_count >= "01001101") and (bit_count <= "01100000") then 	-- from 77 to 96
																										-- Slot 4 : right channel
				right_in_data <= right_in_data(18 downto 0) & ac97_sdata_in;		-- concat incoming bits on end
			end if;
		end if;
	end process;

end arch;


--/////////////// STATE MACHINE TO CONFIGURE THE AC97 ///////////////////////////--



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- one can add extra inputs and signals to control the input to LM4550 (ac97) register map below see volume and source for example
entity ac97cmd is
	port (
		 clk      			: in  std_logic;
		 ac97_ready_sig   : in  std_logic;
		 cmd_addr 			: out std_logic_vector(7 downto 0);
		 cmd_data 			: out std_logic_vector(15 downto 0);
		 latching_cmd		: out std_logic;
		 volume   			: in  std_logic_vector(4 downto 0);  			-- input for encoder for volume control 0->31
		 source   			: in  std_logic_vector(2 downto 0)); 			-- 000 = Mic, 100=LineIn
end ac97cmd;



architecture arch of ac97cmd is
	signal cmd 		: std_logic_vector(23 downto 0);  
	signal atten   : std_logic_vector(4 downto 0);							-- used to set atn in 04h ML4:0/MR4:0
	type state_type is (S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11);
	signal cur_state, next_state : state_type;
begin
																							-- parse command from data
   cmd_addr <= cmd(23 downto 16);
   cmd_data <= cmd(15 downto 0);
   atten      <= std_logic_vector(31 - unsigned(volume));      		-- convert vol to attenuation

	-- USED TO DETERMINE IF THE REGISTER ADDRESS IS VALID 
	-- one can add more with select statments with output signals to do more error checking
	---------------------------------------------------------------------------------------------
	with cmd(23 downto 16) select
		latching_cmd <=
			'1' when X"02" | X"04" | X"06" | X"0A" | X"0C" | X"0E" | X"10" | X"12" | X"14" | 
						X"16" | X"18" | X"1A" | X"1C" | X"20" | X"22" | X"24" | X"26" | X"28" | 
						X"2A" | X"2C" | X"32" | X"5A" | X"74" | X"7A" | X"7C" | X"7E" | X"80",
			'0' when others;
			
	
	-- go through states based on input pulses from ac97 ready signal
	------------------------------------------------------------------------------------------
	process(clk, next_state, cur_state)
		begin
																
		if(clk'event and clk = '1') then
			if ac97_ready_sig = '1' then
				cur_state <= next_state;
			end if;
		end if;
	end process;
	
		
	-- use state machine to configure controller
	-- refer to register map on LM4550 data sheet 
	-- signals and input busses can be added to control 
	-- the AC97 codec refer to the source and volume to see how
	-- first part is address, second part after _ is command
	-- states and input signals can be added for real time configuration of 
	-- any ac97 register
	-------------------------------------------------------------------------------------------
	process (next_state, cur_state, atten, source)
	begin

		case cur_state is
			when S0 =>
				cmd <= X"02_8000";  												-- master volume	0 0000->0dB atten, 1 1111->46.5dB atten								
				next_state <= S2;
			when S1 => 
				cmd <= X"04" & "000" & atten & "000" & atten;			-- headphone volume
				next_state <= S4;
			when S2 => 
				cmd <= X"0A_0000";  												-- Set pc_beep volume
				next_state <= S11;
			when S3 => 
				cmd <= X"0E_8048";  												-- Mic Volume set to gain of +20db
				next_state <= S10;
			when S4 => 
				cmd <= X"18_0808";  												-- PCM volume
				next_state <= S6;
			when S5 =>
				cmd <= X"1A" & "00000" & source & "00000" & source;  	-- Record select reg 000->Mic, 001->CD in l/r, 010->Video in l/r, 011->aux in l/r
				next_state <= S7;													-- 100->line_in l/r, 101->stereo mix, 110->mono mix, 111->phone input
			when S6 =>
				cmd <= X"1C_0F0F";  												-- Record gain set to max (22.5dB gain)
				next_state <= S8;	
			when S7 =>
				cmd <= X"20_8000";  												-- PCM out path 3D audio bypassed
				next_state <= S0;
			when S8 => 
				cmd <= X"2C_BB80";   											-- DAC rate 48 KHz,	can be set to 1F40 = 8Khz, 2B11 = 11.025KHz, 3E80 = 16KHz,											 
				next_state <= S5;													-- 5622 = 22.05KHz, AC44 = 44.1KHz, BB80 = 48KHz
			when S9 =>
				cmd <= X"32_BB80";  												-- ADC rate 48 KHz,	can be set to 1F40 = 8Khz, 2B11 = 11.025KHz, 3E80 = 16KHz,									 
				next_state <= S3;													-- 5622 = 22.05KHz, AC44 = 44.1KHz, BB80 = 48KHz	
			when S10 =>
				cmd <= X"80_0000";  							  					
				next_state <= S9;
			when S11 =>
				cmd <= X"80_0000";  												
				next_state <= S1;
			end case;
	 
  end process;

end arch;







