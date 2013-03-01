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

		-- CPU Port
		Address       : in  std_logic_vector(2 downto 0); -- Register address
		Data_in       : in  std_logic_vector(2 downto 0); -- Write data
		Data_out      : out std_logic_vector(2 downto 0); -- Read data
		WE            : in  std_logic;  -- Write

		-- Control lines
		EndOfScanline : in  std_logic;  -- Goes up at scanline dot #256

		Loopy_v       : out std_logic_vector(14 downto 0);

	);
end entity Loopy_Scrolling;

architecture RTL of Loopy_Scrolling is
--	
--	yyy NN YYYYY XXXXX
--	||| || ||||| +++++-- coarse X scroll
--	||| || +++++-------- coarse Y scroll
--	||| ++-------------- nametable select
--	+++----------------- fine Y scroll

begin
end architecture RTL;
