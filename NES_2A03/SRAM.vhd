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
		--Clock				: in std_logic;
		ChipSelect_N	: in std_logic;
		ReadEnable_N	: in std_logic;
		WriteEnable_N	: in std_logic;
		OutputEnable_N : in std_logic;
		Address			: in std_logic_vector (10 downto 0);
		Data				: inout std_logic_vector (7 downto 0);
		Reading			: out std_logic;
		Writing			: out std_logic
	);
end SRAM;

architecture Behavioral of SRAM is
	-- Declare Memory type
	type Memory is array(0 to 2047) of std_logic_vector (7 downto 0);
	signal CPUMemory : Memory;
	
begin
   process (ChipSelect_N, ReadEnable_N, OutputEnable_N)
   begin
     -- if (rising_edge(Clock)) then
			if (ChipSelect_N = '0') then
				if (ReadEnable_N = '0') then
		         if (OutputEnable_N = '0') then
						Data <= CPUMemory(to_integer(unsigned(Address)));
						Reading <= '1';
					else
						Data <= "ZZZZZZZZ";
						Reading <= '0';
					end if;
					-- might want to add
					--Data <= "ZZZZZZZZ";
					--Reading <= '0';
						--here
				end if;
				
			else
				Data <= "ZZZZZZZZ";
				Reading <= '0';
			end if;
		--end if;
   end process;
	process (WriteEnable_N)
	begin
		if falling_edge(WriteEnable_N) then
			if (ChipSelect_N = '0') then
					--Data <= "ZZZZZZZZ";--might want this back later
	            CPUMemory(to_integer(unsigned(Address))) <= Data;
					Writing <= '1';
			else
					Writing <= '0';
			end if;
		else
			--Writing <= '0';
		end if;
	end process;
end Behavioral;

--comments
--could buffer data and throw that signal on the bus or ZZZZZZZ depending on
	--output enable/chip select