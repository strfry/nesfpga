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



begin
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