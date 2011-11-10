--Dan Leach
--Clock divider (divide by twelve, seven cycle duty cycle)
--Created 1/03/06
	--Initial revision
--Modified 1/27/06
	--Changed if statements so that Clk_Out is set after the first input clock
    --	cycle.  Also added another clause so that the counter is reset after
	--	12 input cycles.
	--Set default/initial values of all pins
--Modified sometime since then
	--Added PHI2 signal, inverse of PHI1/Clk_Out
--Modified 6/27/06
	--Need another signal to use when reading data from the bus
	--  this means another signal goes high 2 input clock cycles
	--  after Clk_Out_Phi2 goes high
--Modified 7/01/06
	--Need another signal for putting the address on the bus shortly after
	--  PHI1 (Clk_Out_Phi2) goes high
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Library UNISIM;
use UNISIM.vcomponents.all;

entity Clock_Divider is
	port(Clk_In, Reset_N, Enable : in std_logic;
		Clk_Out : out std_logic;
		Clk_Out_Phi2 : out std_logic;
		Clk_Out_AddOK : out std_logic;
		Clk_Out_WriteOK : out std_logic;
		Clk_Out_ReadOK : out std_logic;
		In_Out : buffer std_logic := '0');
end Clock_Divider;

architecture Behavior of Clock_Divider is
constant Duty : unsigned (3 downto 0) := "1000";	--5 cycle duty cycle
constant Total : unsigned (3 downto 0) := "1011";--"1011";	--12 cycles total
constant WriteOK : unsigned (3 downto 0) := "0010";	--Read 2 cycles into Phi2
constant ReadOK : unsigned (3 downto 0) := "0101";	--Read 3 cycles into Phi2
constant AddOK : unsigned (3 downto 0) := "1001";  --Address valid 1 cycle into Phi1
signal Count_Out_W : unsigned (3 downto 0);

signal PLL_FB : std_logic;


begin
--PLL_BASE_inst : PLL_BASE
--	generic map (
--		BANDWIDTH => "OPTIMIZED",  -- "HIGH", "LOW" or "OPTIMIZED" 
--		CLKFBOUT_MULT => 10,        -- Multiplication factor for all output clocks
--		CLKFBOUT_PHASE => 0.0,     -- Phase shift (degrees) of all output clocks
--		CLKIN_PERIOD => 10.000,     -- Clock period (ns) of input clock on CLKIN
--		CLKOUT0_DIVIDE => 120,       -- Division factor for CLKOUT0  (1 to 128)
--		CLKOUT0_DUTY_CYCLE => 0.3333, -- Duty cycle for CLKOUT0 (0.01 to 0.99)
--		CLKOUT0_PHASE => 0.0,      -- Phase shift (degrees) for CLKOUT0 (0.0 to 360.0)
--		CLKOUT1_DIVIDE => 120,       -- Division factor for CLKOUT1 (1 to 128)
--		CLKOUT1_DUTY_CYCLE => 0.6666, -- Duty cycle for CLKOUT1 (0.01 to 0.99)
--		CLKOUT1_PHASE => 120.0,      -- Phase shift (degrees) for CLKOUT1 (0.0 to 360.0)
--		CLKOUT2_DIVIDE => 120,       -- Division factor for CLKOUT2 (1 to 128)
--		CLKOUT2_DUTY_CYCLE => 0.4166, -- Duty cycle for CLKOUT2 (0.01 to 0.99)
--		CLKOUT2_PHASE => 30.0,      -- Phase shift (degrees) for CLKOUT2 (0.0 to 360.0)
--		CLKOUT3_DIVIDE => 120,       -- Division factor for CLKOUT3 (1 to 128)
--		CLKOUT3_DUTY_CYCLE => 0.5, -- Duty cycle for CLKOUT3 (0.01 to 0.99)
--		CLKOUT3_PHASE => 180.0,      -- Phase shift (degrees) for CLKOUT3 (0.0 to 360.0)
--		CLKOUT4_DIVIDE => 120,       -- Division factor for CLKOUT4 (1 to 128)
--		CLKOUT4_DUTY_CYCLE => 0.1666, -- Duty cycle for CLKOUT4 (0.01 to 0.99)
--		CLKOUT4_PHASE => 180.0,      -- Phase shift (degrees) for CLKOUT4 (0.0 to 360.0)
--		CLKOUT5_DIVIDE => 1,       -- Division factor for CLKOUT5 (1 to 128)
--		CLKOUT5_DUTY_CYCLE => 0.5, -- Duty cycle for CLKOUT5 (0.01 to 0.99)
--		CLKOUT5_PHASE => 0.0,      -- Phase shift (degrees) for CLKOUT5 (0.0 to 360.0)
--		COMPENSATION => "SYSTEM_SYNCHRONOUS",  -- "SYSTEM_SYNCHRNOUS", 
--															-- "SOURCE_SYNCHRNOUS", "INTERNAL", 
--															-- "EXTERNAL", "DCM2PLL", "PLL2DCM" 
--		DIVCLK_DIVIDE => 1,      -- Division factor for all clocks (1 to 52)
--		REF_JITTER => 0.100)     -- Input reference jitter (0.000 to 0.999 UI%)
--	port map (
--		CLKFBOUT => PLL_FB,      -- General output feedback signal
--		CLKOUT0 => Clk_Out,        -- One of six general clock output signals
--		CLKOUT1 => Clk_Out_Phi2,        -- One of six general clock output signals
--		CLKOUT2 => Clk_Out_AddOK,        -- One of six general clock output signals
--		CLKOUT3 => Clk_Out_WriteOK,        -- One of six general clock output signals
--		CLKOUT4 => Clk_Out_AddOK,        -- One of six general clock output signals
--		CLKOUT5 => open,        -- One of six general clock output signals
--		LOCKED => open,          -- Active high PLL lock signal
--		CLKFBIN => PLL_FB,        -- Clock feedback input
--		CLKIN => Clk_In,            -- Clock input
--		RST => "not"(Reset_N)                 -- Asynchronous PLL reset
--	);

	--Debugging
	In_Out <= Clk_In;
	
	Count : process(Clk_In, Reset_N)
	begin
		if (Reset_N = '0') then
			Clk_Out <= '0';
			Clk_Out_Phi2 <= '0';
			Clk_Out_ReadOK <= '0';
			Count_Out_W <= (others => '0');	
		elsif (falling_edge(Clk_In)) then
			if (Enable = '1') then
				case Count_Out_W is
					when "0000" =>
						Clk_Out <= '0';
						Clk_Out_Phi2 <= '1';
						Count_Out_W <= Count_Out_W + 1;
					when WriteOK =>
						Clk_Out_WriteOK <= '1';
						Clk_Out_AddOK <= '0';
						Count_Out_W <= Count_Out_W + 1;
					when AddOK =>
						Clk_Out_AddOK <= '1';
						Count_Out_W <= Count_Out_W + 1;
					when Duty =>
						Clk_Out <= '1';
						Clk_Out_Phi2 <= '0';
						Clk_Out_AddOK <= '0';
						Clk_Out_WriteOK <= '0';
						Clk_Out_ReadOK <= '0';
						Count_Out_W <= Count_Out_W + 1;
					when ReadOK =>
						Clk_Out_ReadOK <= '1';
						Count_Out_W <= Count_Out_W + 1;
					when Total =>
						Clk_Out <= '1';
						Clk_Out_Phi2 <= '0';
						
						Count_Out_W <= (others => '0');
					when others =>
						Count_Out_W <= Count_Out_W + 1;
				end case;
			end if;
		end if;
	end process;
end Behavior;