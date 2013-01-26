
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

entity TileFetcher is	
port  (
		CLK : in std_logic;
		CE : in std_logic;
		RSTN : in std_logic;

		HPOS : in integer;
		VPOS : in integer;

		VRAM_Address: out unsigned(13 downto 0);
		VRAM_Data : in std_logic_vector(7 downto 0);

		HorizontalScrollOffset : in unsigned(7 downto 0);
		VerticalScrollOffset : in unsigned(7 downto 0);
		PatternTableAddressOffset : in std_logic;
		NameTableAddressOffset : in std_logic_vector(1 downto 0);

		TileColor : out unsigned(3 downto 0)
      );
end TileFetcher;

architecture Behavioral of TileFetcher is

	
	signal TilePattern0 : std_logic_vector(15 downto 0);
	signal TilePattern1 : std_logic_vector(15 downto 0);
	signal TileAttribute : std_logic_vector(15 downto 0);
	
begin
	
	process (VPOS, HPOS, TilePattern0, TilePattern1, TileAttribute)
	variable attr_pos : integer;
	variable attr_color : unsigned(1 downto 0);
	variable bg_color : unsigned(3 downto 0);
	begin
		attr_pos := ((VPOS mod 32) / 16) * 4 + (HPOS mod 32) / 16 * 2;
		attr_color := unsigned(TileAttribute(attr_pos + 1 downto attr_pos));
		
		--attr_color := unsigned(TilePipeline(0).attr(1 downto 0));
		TileColor <= attr_color & TilePattern1(15 - HPOS mod 8) & TilePattern0(15 - HPOS mod 8);
		
		if VPOS >= 210 then
			TileColor <= to_unsigned((HPOS / 8) mod 16, 4);
		end if;
	end process;

	PREFETCH : process(clk, rstn)
		variable NameTableBaseAddress : integer;
		variable PatternTableBaseAddress : integer;
		variable address : integer;
		variable Prefetch_XPOS : integer;
		variable Prefetch_YPOS : integer;

		variable NextTileName : unsigned(7 downto 0);
		variable NextTilePattern0 : std_logic_vector(7 downto 0);
		variable NextTileAttribute : std_logic_vector(7 downto 0);
	begin
		if rstn = '0' then
			VRAM_Address <= (others => '0');
		elsif rising_edge(clk) and CE = '1' then			
			Prefetch_XPOS := (HPOS + 16 + to_integer(HorizontalScrollOffset)) mod 256;
			if HPOS > 240 then
				Prefetch_YPOS := VPOS + 1;
			else 
				Prefetch_YPOS := VPOS;
			end if;
			
			Prefetch_YPOS := (Prefetch_YPOS + to_integer(VerticalScrollOffset)) mod 256;
			
			PatternTableBaseAddress := 0;
			if PatternTableAddressOffset = '1' then
			  PatternTableBaseAddress := 4096;
			end if;
			
			
			NameTableBaseAddress := 8192;
			-- Select right-hand nametable when it is selected, or when scrolled in, and mirror back to the left when both is the case
			if Prefetch_XPOS + HorizontalScrollOffset >= 256 xor NametableAddressOffset(0) = '1' then
				NametableBaseAddress := NametableBaseAddress + 1024;
			end if;
			
			-- Same thing for vertical scroll
			if Prefetch_YPOS + VerticalScrollOffset >= 256 xor NametableAddressOffset(1) = '1' then
				NametableBaseAddress := NametableBaseAddress + 2048;
			end if;
			
			address := 0;
			
			--PPU_Address <= (others => '0');
			
--			if HPOS >= -15 and HPOS < 240 and VPOS >= -1 and VPOS < 240 then
			if HPOS >= -15 and HPOS < 240 and VPOS >= -1 and VPOS < 240 then
--			if HPOS < 240 and VPOS < 240 then
				case HPOS mod 8 is
					when 0 =>
						address := NameTableBaseAddress + Prefetch_XPOS / 8 + (Prefetch_YPOS / 8) * 32;
						VRAM_Address <= to_unsigned(address, VRAM_Address'length);
					when 1 =>
						NextTileName := unsigned(VRAM_Data);
--						NextTileName := to_unsigned((Prefetch_XPOS / 8) mod 16 + (Prefetch_YPOS / 8) * 8, 8);
--						NextTileName := X"23";
					when 2 =>
						address :=  NameTableBaseAddress + 960 + (Prefetch_XPOS - 2) / 32 + (Prefetch_YPOS / 32) * 8;
						VRAM_Address <= to_unsigned(address, VRAM_Address'length);
					when 3 =>
						NextTileAttribute := VRAM_Data;
					when 4 =>						
						address := PatternTableBaseAddress + to_integer(NextTileName * 16 + (Prefetch_YPOS mod 8));
						VRAM_Address <=  to_unsigned(address, VRAM_Address'length);
					when 5 =>
						NextTilePattern0 := VRAM_Data;
					when 6 =>
						
						address := PatternTableBaseAddress + to_integer(NextTileName * 16 + (Prefetch_YPOS mod 8) + 8);
						VRAM_Address <=  to_unsigned(address, VRAM_Address'length);
						
					when 7 =>
						TilePattern1 <= VRAM_Data & TilePattern1(15 downto 8);
						TilePattern0 <= NextTilePattern0 & TilePattern0(15 downto 8);
						TileAttribute <= NextTileAttribute & TileAttribute(15 downto 8);
						
--						TileAttribute <= "0000000000000000";
--						TilePattern0 <= "0011001100110011";
--						TilePattern1 <= "0000111100001111";
					when others =>
				end case;
			end if;
		
		end if;
	end process;


end Behavioral;

