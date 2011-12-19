--------------------------------------------------------------------------------
-- Entity: NES_2C02
-- Date:2011-10-24  
-- Author: jonathansieber     
--
-- Description ${cursor}
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity NES_2C02 is
	port  (
        clk : in std_logic;        -- approximation to NES mainboard clock 21.47727
        rstn : in std_logic;
        
        -- CPU Bus
        ChipSelect_n : in std_logic;
        ReadWrite : in std_logic; -- Write to PPU on 0
        Address : in std_logic_vector(2 downto 0);
        Data_in : in std_logic_vector(7 downto 0);
        Data_out : out std_logic_vector(7 downto 0);
        
        -- VRAM/VROM bus
        CHR_Address : out unsigned(13 downto 0);
        CHR_Data : in std_logic_vector(7 downto 0);
        
        VBlank_n : out std_logic; -- Tied to the CPU's Non-Maskable Interrupt (NMI)     
        
        -- Framebuffer output
        FB_Address : out std_logic_vector(15 downto 0); -- linear index in 256x240 pixel framebuffer
        FB_Color : out std_logic_vector(5 downto 0); -- Palette index of current color
        FB_DE : out std_logic    -- True when PPU is writing to the framebuffer
	);
end NES_2C02;

architecture arch of NES_2C02 is

	signal HSYNC_cnt : integer := 0;
	signal VSYNC_cnt : integer := 0;
	signal HPOS : integer;
	signal VPOS : integer;
	
	signal CE_cnt : unsigned(1 downto 0) := "00";
	signal CE : std_logic;
	
	signal VBlankFlag : std_logic := '0';
	signal HitSpriteFlag : std_logic := '0';
	
	signal Status_2000 : std_logic_vector(7 downto 0) := "00000000";
	signal Status_2001 : std_logic_vector(7 downto 0) := "00000000";
		
	signal Data_in_d : std_logic_vector(7 downto 0) := "00000000";
	signal CPUPortDir : std_logic;
	
	signal ChipSelect_delay : std_logic;
	
	signal VerticalScrollOffset : unsigned(7 downto 0);
	signal HorizontalScrollOffset : unsigned(7 downto 0);
	
	signal PPU_Address : unsigned(13 downto 0);
	signal PPU_Data_r : std_logic_vector(7 downto 0);
	signal PPU_Data_w : std_logic_vector(7 downto 0);
--	signal VRAMData_in : std_logic_vector(7 downto 0);
--	signal VRAMData_out : std_logic_vector(7 downto 0);
	
	
	signal CPUVRAMAddress : unsigned(13 downto 0);
	signal CPUVRAMRead : std_logic;
	signal CPUVRAMWrite : std_logic;
	
	type VRAMType is array(2047 downto 0) of std_logic_vector(7 downto 0);
	type PaletteRAMType is array(31 downto 0) of std_logic_vector(5 downto 0);
	
	signal VRAMData : VRAMType := (
		0 => X"00",
		1 => X"01",
		2 => X"02",
		3 => X"03",
		4 => X"04",
		5 => X"05",
		6 => X"06",
		7 => X"07",
		8 => X"08",
		9 => X"09",
		20 => X"11",
		21 => X"12",
		22 => X"13",
		23 => X"04",
		24 => X"05",
		25 => X"06",
		26 => X"07",
		27 => X"08",
		29 => X"09",
		30 => X"0a",
		50 => X"0b",
		51 => X"0c",
		52 => X"0d",
		53 => X"0e",
		54 => X"0f",
		55 => X"13",
		56 => X"12",
		57 => X"11",
		58 => X"1d",
		59 => X"1c",
		100 => X"1b",
		101 => X"20",
		102 => X"40",
		103 => X"50",
		104 => X"60",
		105 => X"60",
		106 => X"60",
		107 => X"70",
		108 => X"80",
		109 => X"a0",
		others => "00000000"
	);
	
	signal PaletteRAM : PaletteRAMType := (
--		0 =>  "000000",
--		1 =>  "000001",
--		2 =>  "000010",
--		3 =>  "000011",
--		4 =>  "000100",
--		5 =>  "000101",
--		6 =>  "000110",
--		7 =>  "000111",
--		8 =>  "001000",
--		9 =>  "001001",
--		10 => "001010",
--		11 => "001011",
--		12 => "001100",
--		13 => "001101",
--		14 => "001110",
--		15 => "001111",
--		16 => "010000",
--		17 => "010001",
--		18 => "010010",
--		19 => "010011",
--		20 => "010100",
--		21 => "010101",
--		22 => "010110",
--		23 => "010111",
--		24 => "011000",
--		25 => "011001",
--		26 => "011010",
--		27 => "011011",
--		28 => "011100",
--		29 => "011101",
--		30 => "011110",
--		31 => "011111"
		others => "UUUUUU"
	);
	
	type SpriteMemDataType is array(255 downto 0) of std_logic_vector(7 downto 0);
	signal SpriteMemAddress : unsigned(7 downto 0);
	signal SpriteMemData : SpriteMemDataType := (others => (others => '0'));
	
	type BackgroundTile is
		record
			attr : std_logic_vector(7 downto 0);
			pattern0 : std_logic_vector(7 downto 0);
			pattern1 : std_logic_vector(7 downto 0);
	end record;
	
	type BackgroundTilePipelineType is array (0 to 2) of BackgroundTile;
	
	signal TilePipeline : BackgroundTilePipelineType;
	signal BGTileName : unsigned(7 downto 0);
	
	type SpriteCacheEntry is record
		x : unsigned(7 downto 0);
		name : unsigned(7 downto 0);
		attr : unsigned(7 downto 0);
		y : unsigned(7 downto 0);
		pattern0 : unsigned(7 downto 0);
		pattern1 : unsigned(7 downto 0);
	end record;
	
	type SpriteCacheType is array (0 to 7) of SpriteCacheEntry;
	
	signal SpriteCache : SpriteCacheType;	
	
	signal SpritesFound : integer range 0 to 8;
	signal SpriteCounter : integer range 0 to 64;
	
	
	signal CurrentSpriteColor : unsigned(1 downto 0);
begin

	CHR_Address <= PPU_Address;
	
	VBlank_n <= VBlankFlag nand Status_2000(7); -- Check on flag and VBlank Enable
	HPOS <= HSYNC_cnt - 42;
	VPOS <= VSYNC_cnt - 20;
	
	CE <= '1' when CE_cnt = 0 else '0';
	
	process (clk)
	begin
		if rising_edge(clk) then
			CE_cnt <= CE_cnt + 1;
		end if;
	end process;
	
	process (clk)
	begin
		if rising_edge(clk) and CE = '1' then
			if HSYNC_cnt < 341 - 1 then
				HSYNC_cnt <= HSYNC_cnt + 1;
			else
				HSYNC_cnt <= 0;
				if VSYNC_cnt < 262 - 1 then
					VSYNC_cnt <= VSYNC_cnt + 1;
				else
					VSYNC_cnt <= 0;
				end if;
			end if;
		end if;
	end process;
	
	SPRITE_BUFFER_MUX : process (clk)
	variable sprite : SpriteCacheEntry;
	begin
	    if rising_edge(clk) and CE = '1' then
	    
	        for i in 0 to 7 do
	            sprite <= SpriteCache(i);
	            if sprite.x < 8 then
	                CurrentSpriteColor <= sprite.pattern0(sprite.x) & sprite.pattern1(sprite.x);
	            end if;
	            SpriteCache(i).x <= sprite.x - 1;
	        loop;
	    end if;
	end process;
	
	process (clk)
	variable attr_pos : integer;
	variable attr_color : unsigned(1 downto 0);
	variable bg_color : unsigned(3 downto 0);
	begin
		if rising_edge(clk) and CE = '1' then
			if HPOS >= 0 and HPOS < 256 and VPOS >= 0 and VPOS < 240 then
				FB_DE <= '1';
				FB_Address <= std_logic_vector(to_unsigned(VPOS * 256 + HPOS, FB_Address'length));
				
				attr_pos := ((VPOS mod 32) / 16) * 4 + (HPOS mod 32) / 16 * 2;
				attr_color := unsigned(TilePipeline(0).attr(attr_pos + 1 downto attr_pos));
				
				--attr_color := unsigned(TilePipeline(0).attr(1 downto 0));
				bg_color := attr_color & TilePipeline(0).pattern1(7 - HPOS mod 8) & TilePipeline(0).pattern0(7 - HPOS mod 8);
				
				--FB_Color <= std_logic_vector(to_unsigned(HPOS / 16, FB_Color'length));
				FB_Color <= std_logic_vector(PaletteRAM(to_integer(bg_color)));
				--FB_Color <= std_logic_vector(PaletteRAM(to_integer(bg_color(1 downto 0))));
				
				--FB_Color <= std_logic_vector(to_unsigned(attr_pos, 6));
				
				--FB_Color <= "00" & TilePipeline(0).pattern1(HPOS mod 8) & TilePipeline(0).pattern0(HPOS mod 8) & "00";
				
				if SpritesFound > 0 then
					if SpriteCache(0).x - HPOS < 8 then FB_Color <= "101111"; end if;
				end if;
				
				
				if VPOS >= 230 then
					FB_Color <= std_logic_vector(PaletteRAM(HPOS / 8));
				end if;
				
				if HPOS < 0 or HPOS >= 256 or VPOS < 0 or VPOS >= 240 then
					FB_Color <= "000000";
				end if;
				
			else
				FB_DE <= '0';
			end if;
		end if;
	end process;
	
	
	CPU_PORT : process (clk)
	begin	
		if rising_edge(clk) then	
			if CE = '1' then
				if HPOS >= 0 and HPOS < 3 and VPOS = 0 then -- Start VBlank period
					VBlankFlag <= '1';
				elsif HPOS >= 0 and HPOS < 3 and VPOS = 20 then -- End VBlank Period
					VBlankFlag <= '0';
				end if;
	
				
				
		    	CPUVRAMWrite <= '0';
		    	CPUVRAMRead <= '0';

		    	
		    	if CPUVRAMRead = '1' or CPUVRAMWrite = '1' then
					if (Status_2000(2) = '0') then
						CPUVRAMAddress <= CPUVRAMAddress + 1;
					else
						CPUVRAMAddress <= CPUVRAMAddress + 32;
					end if;
			    end if;			
			end if;
			

			ChipSelect_delay <= ChipSelect_n;
			Data_in_d <= Data_in;
				
			-- Do reads on low CS, and writes on rising edge
			
			if ChipSelect_n = '1' and ChipSelect_delay = '0' then
				if ReadWrite = '0' then
					if Address = "000" then
						Status_2000 <= Data_in_d;
					elsif Address = "001" then
						Status_2001 <= Data_in_d;
					elsif Address = "011" then
						SpriteMemAddress <= unsigned(Data_in_d);
					elsif Address = "100" then
						SpriteMemData(to_integer(SpriteMemAddress)) <= Data_in_d;
						SpriteMemAddress <= SpriteMemAddress + 1;
					elsif Address = "101" then
						if CPUPortDir = '0' then
							if unsigned(Data_in_d) <= 239 then
								VerticalScrollOffset <= unsigned(Data_in_d);
							end if;
						else
							HorizontalScrollOffset <= unsigned(Data_in_d);
						end if;
						CPUPortDir <= not CPUPortDir;						
					elsif Address = "110" then
						if CPUPortDir = '0' then
							CPUVRAMAddress(13 downto 8) <= unsigned(Data_in_d(5 downto 0));
						else
							CPUVRAMAddress(7 downto 0) <= unsigned(Data_in_d);
						end if;						
						CPUPortDir <= not CPUPortDir;					
					elsif Address = "111" then
						CPUVRAMWrite <= '1';
						PPU_Data_w <= Data_in_d;
					end if;
				elsif Address = "010" then
					CPUPortDir <= '0';
					if VBlankFlag = '1' then
						VBlankFlag <= '0';
					end if; -- Reset VBlankFlag only once on write event
				end if;
			
			elsif ChipSelect_n = '0' and ReadWrite = '1' then
				if Address = "000" then
					Data_out <= Status_2000;
				elsif Address = "001" then
					Data_out <= Status_2001;
				elsif Address = "010" then
					--Data_out <= (6 => HitSpriteFlag, 7 => VBlankFlag, others => '0');
					Data_out <= (6 => HitSpriteFlag, 7 => '1', others => '0');
				elsif Address = "100" then
					Data_out <= SpriteMemData(to_integer(SpriteMemAddress));
					SpriteMemAddress <= SpriteMemAddress + 1;
				elsif Address = "111" then
					Data_out <= PPU_Data_r;
					CPUVRAMRead <= '1';
				else
					Data_out <= (others => 'X'); -- This should be a write only register
				end if;
			end if;
		end if;
	end process;
	
	TILE_PREFETCH : process(clk, rstn)
		variable address : integer;
		variable Prefetch_XPOS : integer;
		variable Prefetch_YPOS : integer;
		variable currentSprite : SpriteCacheType:
	begin
		if rstn = '0' then
			PPU_Address <= (others => '0');
		elsif rising_edge(clk) and CE = '1' then
			address := 0;
			
			Prefetch_XPOS := HPOS + 16;
			if HPOS > 240 then
				Prefetch_YPOS := (VPOS + 1);
			else 
				Prefetch_YPOS := VPOS;
			end if;
			
			--PPU_Address <= (others => '0');
			
			if Prefetch_XPOS >= 0 and Prefetch_XPOS < 256 and Prefetch_YPOS >= 0 and Prefetch_YPOS < 240 then
				case HPOS mod 8 is
					when 0 =>
						--TilePipeline(1).pattern1 <= PPU_Data_r;
						TilePipeline(1).pattern1 <= "00110011";
						--TilePipeline(1).pattern1 <= "00110011";
						address := 8192 + Prefetch_XPOS / 8 + (Prefetch_YPOS / 8) * 32;
						PPU_Address <= to_unsigned(address, PPU_Address'length);
					when 1 =>
					when 2 =>
						BGTileName <= unsigned(PPU_Data_r);
						--BGTileName <= X"24";
						--BGTileName <= to_unsigned(8192 + HPOS / 8 + VPOS / 8 * 32, 8);
						address :=  9152 + (Prefetch_XPOS - 2) / 32 + (Prefetch_YPOS / 32) * 8;
						PPU_Address <= to_unsigned(address, PPU_Address'length);
					when 3 =>
					when 4 =>
						TilePipeline(2).attr <= PPU_Data_r;
						if Status_2000(4) = '1' then
							address := 4096;
						end if;
						
						address := address + to_integer(BGTileName * 16 + (Prefetch_YPOS mod 8));
						PPU_Address <=  to_unsigned(address, PPU_Address'length);
					when 5 =>
					when 6 =>
						TilePipeline(2).pattern0 <= PPU_Data_r;
						--TilePipeline(2).pattern0 <= "00001111";
						if Status_2000(4) = '1' then
							address := 4096;
						end if;
						
						address := address + to_integer(BGTileName * 16 + (Prefetch_YPOS mod 8) + 8);
						PPU_Address <=  to_unsigned(address, PPU_Address'length);
						
					when 7 =>
						TilePipeline(0 to 1) <= TilePipeline(1 to 2);
					when others =>
				end case;
		    elsif Prefetch_XPOS >= 256 and Prefetch_XPOS < 288 and Prefetch_YPOS >= 0 and Prefetch_YPOS < 240 then
		    
		        if Status_2000(5) = '1' then
				    address := 4096;
			    end if;
		        case Prefetch_XPOS mod 8 then -- Original PPU reuses the tile fetching state machine, so do here
		            when 4 =>
		                currentSprite <= SpriteCache(Prefetch_XPOS - 260 / 8)<
    		            -- Compute Sprite number implicitly from XPOS
	    	            PPU_Address <= to_unsigned(address + 16 * currentSprite.name + currentSprite mod 8); 
	    	        when 6 =>
	    	            SpriteCache(Prefetch_XPOS - 260 / 8).pattern0 <= PPU_Data_r:
	    	            PPU_Address <= to_unsigned(address + 16 * currentSprite.name + currentSprite mod 8 + 8);
	    	        when 0 =>
	    	            SpriteCache(Prefetch_XPOS - 260 / 8).pattern1 <= PPU_Data_r;
	    	    end case;
			end if;
		
		end if;
	end process;
	
	RAM_ACCESS : process (clk)
	variable InternalRW : std_logic;
	variable InternalAddress : unsigned(13 downto 0);
	begin
		if rising_edge(clk) and CE = '1' then
			if CPUVRAMRead = '1' then
				InternalRW := '1';
				InternalAddress := CPUVRAMAddress;
			elsif CPUVRAMWrite = '1' then
				InternalRW := '0';
				InternalAddress := CPUVRAMAddress;
			else
				InternalRW := '1';
				InternalAddress := PPU_Address;
			end if;
			
			-- The 2C02 addresses the PPU memory bus with an 8 bit port
			-- and an address latch, so all memory accesses except for internal
			-- palette RAM should take 2 Cycles, which is implemented by this process
											
			if InternalAddress(13 downto 8) = X"3F" then
				-- Palette RAM Access takes just a single cycle
				if InternalRW = '1' then
					PPU_Data_r <= "00" & PaletteRAM(to_integer(InternalAddress(4 downto 0)));
				else
					PaletteRAM(to_integer(InternalAddress(4 downto 0))) <= PPU_Data_w(5 downto 0);
				end if;
			else 
				if InternalAddress(13 downto 12) = "10" then -- SRAM
					-- The cartridge has tri-state access to the address lines A10/A11,
					-- so it can either provide additional 2k of SRAM, or tie them down
					-- to mirror the address range of the upper nametables to the lower ones
					
					-- Super Mario Brothers selects vertical mirroring (A11 tied down),
					-- so thats what we are doing here for now
					
					if InternalRW = '1' then
						PPU_Data_r <= VRAMData(to_integer(InternalAddress(10 downto 0)));
					else
						VRAMData(to_integer(InternalAddress(10 downto 0))) <= PPU_Data_w;
					end if;
				else -- Cartridge CHR-RAM/ROM
					-- CHR-RAM unimplemented for now
					PPU_Data_r <= CHR_Data;
				end if;
			end if;
		end if;
	end process;
	
	SPRITE_LOOKUP : process (clk, rstn)
	variable currentSprite : SpriteCacheEntry;
	begin
		if rstn = '0' then
			--SpriteCache <= (others => (others => (others => '0')));
			SpriteCounter <= 0;
		elsif rising_edge(clk) and CE = '1' then
			if VPOS = 0 and HPOS = 0 then
				HitSpriteFlag <= '0';
			end if;
			if HPOS = -1 then
				SpriteCounter <= 0;
				SpritesFound <= 0;
			elsif SpriteCounter < 64 and HPOS >= 0 and HPOS < 256 and VPOS >= 0 and VPOS < 240 then
				if HPOS mod 2 = 0 then
					currentSprite.y := unsigned(SpriteMemData(SpriteCounter * 4));
					currentSprite.x := unsigned(SpriteMemData(SpriteCounter * 4 + 1));
					currentSprite.pattern := unsigned(SpriteMemData(SpriteCounter * 4 + 2));
					currentSprite.attr := unsigned(SpriteMemData(SpriteCounter * 4 + 3));
				else
					if currentSprite.y - VPOS < 8 and currentSprite.y - VPOS > 0 and SpritesFound < 8 then
						SpriteCache(SpritesFound) <= currentSprite;
						
						SpritesFound <= SpritesFound + 1;
						
						if SpriteCounter = 0 then
							HitSpriteFlag <= '1';
						end if;
					end if;
					SpriteCounter <= SpriteCounter + 1;
				end if;
			end if;
		end if;
	end process;

end arch;
