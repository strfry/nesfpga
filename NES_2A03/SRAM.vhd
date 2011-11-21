--Dan Leach
--2K SRAM for NES
--Created 9/10/06
	-- Initial revision
	-- For simplicity, as on the NES itself, the ChipSelect line is used as a clock (Phi2).
	--   This effectively makes the RAM synchronous and thus simpler to implement.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SRAM is
	port(
		Clock				: in std_logic;
		ChipSelect_N	: in std_logic;
		WriteEnable_N	: in std_logic;
		OutputEnable_N : in std_logic;
		Address			: in std_logic_vector (10 downto 0);
		Data				: inout std_logic_vector (7 downto 0)
	);
end SRAM;

architecture Behavioral of SRAM is
	-- Declare Memory type
	type Memory is array(0 to 2047) of std_logic_vector (7 downto 0);
	signal CPUMemory : Memory := (others => (others => 'U'));
	
	signal Data_out : std_logic_vector (7 downto 0);
	
begin
	
	Data <= "ZZZZZZZZ" when ChipSelect_N = '1' or WriteEnable_N = '0' or OutputEnable_N = '1' else Data_out;
--	
--	process (Clock)
--   begin
--      if rising_edge(Clock) then
--			WriteEnable_d <= WriteEnable_N;
--			if ChipSelect_N = '0' and OutputEnable_N = '0' then
--				if WriteEnable_N = '0' and WriteEnable_d = '1' then
--					CPUMemory(to_integer(unsigned(Address))) <= Data;
--				else
--					Data_out <= CPUMemory(to_integer(unsigned(Address)));
--				end if;
--			else
--			end if;
--		end if;
--	end process;
	process (Clock)
   begin
      if rising_edge(Clock) then
			if WriteEnable_N = '0' and ChipSelect_N = '0' then
				CPUMemory(to_integer(unsigned(Address))) <= Data;
			end if;
			
			Data_out <= CPUMemory(to_integer(unsigned(Address)));
		end if;
	end process;
	
end Behavioral;
