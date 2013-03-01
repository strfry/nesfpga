-- Scrolling and PPU Address registers

-- The name Loopy refers to the nickname of the first person in the NES Community to accurately document this registers
-- To save chip are, the PPU reused the counter registers used for Background Tiles as address register for CPU accesses.
-- This can be utilized to change the scrolling mid-screen, which is used by many games, for example to implement a status bar.

-- For more information visit http://wiki.nesdev.com/w/index.php/The_skinny_on_NES_scrolling


library ieee;
use ieee.std_logic_1164.all;

entity Loopy_Scrolling is
	port(
		clk           : in  std_logic;
		CE            : in  std_logic;
		rst           : in  std_logic;

		Loopy_t       : in  std_logic_vector(14 downto 0); -- Temporary register driven by CPU Port		

		Loopy_v       : out std_logic_vector(14 downto 0); -- Counting register

		-- Control lines
		
		ResetXCounter  : in  std_logic; -- Load initial scroll values
		ResetYCounter : in std_logic;
		
		IncXScroll    : in std_logic -- Increment coarse X, at every 8 pixels during scanline rendering
		IncYScroll    : in  std_logic;  -- Increment Y, at scanline dot #256
		
		IncAddress	  : in std_logic; -- Increment Address during $2007 VRAM access
		AddressStep   : in std_logic; -- Increment in steps of 32 instead of 1 
		

	);
end entity Loopy_Scrolling;

architecture RTL of Loopy_Scrolling is

--  counter layout of the loopy registers
--	
--	yyy NN YYYYY XXXXX
--	||| || ||||| +++++-- coarse X scroll
--	||| || +++++-------- coarse Y scroll
--	||| ++-------------- nametable select
--	+++----------------- fine Y scroll

	alias FineYScroll is Loopy_v(14 downto 12);
	alias YNametable is Loopy_v(11);
	alias XNametable is Loopy_v(10);
	alias CoarseYScroll is Loopy_v(9 downto 5);
	alias CoarseXScroll is Loopy_v(4 downto 0);

begin

	process (clk) is
	begin
		if rising_edge(clk) then
			if ResetXCounter = '1' and ResetYCounter = '1' then
				Loopy_v <= Loopy_t;
			elsif ResetXCounter = '1' then
				XNametable <= Loopy_t(10);
				CoarseXScroll <= Loopy_t(4 downto 0);
			elsif ResetYCounter = '1' then
				FineYScrol <= Loopy_t(14 downto 2)
				YNametable <= Loopy_t(11);
				CoarseYScroll <= Loopy_t(9 downto 5);
			elsif IncXScroll = '1' then
				XNameTable & CoarseXScroll <= (XNameTable & CoarseXScroll) + 1;
			elsif IncYScroll = '1' then
				if CoarseYScroll = 29 and FineYScroll = 31 then
					-- Coarse Y acts as a divide-by-30 counter
					
					YNametable <= not YNametable;
					CoarseYScroll <= "00000";
					FineYScroll <= "000";
				else
					CoarseYScroll & FineYScroll <= (CoarseYScroll & FineYScroll) + 1;
				end if;
			elsif IncAddress = '1' and AddressStep = '0' then
				Loopy_v <= Loopy_v + 1;
			elsif IncAddress = '1' and AddressStep = '1' then
				Loopy_v(14 downto 5) <= Loopy(14 downto 5) + 1; 
			end if;
		end if;
	end process ;
	
end architecture RTL;
