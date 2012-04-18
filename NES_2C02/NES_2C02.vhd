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

component SpriteSelector is
	port  (
        CLK : in std_logic;
        CE : in std_logic;
        RSTN : in std_logic;
        
        HPOS : in unsigned(8 downto 0);
        VPOS : in unsigned(8 downto 0);
        
        SpriteColor : out std_logic_vector(3 downto 0);
        SpritePriority : out std_logic;
        SpriteOverflow : out std_logic;
        
        VRAMAddress : out unsigned(13 downto 0);
        VRAMData : in std_logic_vector(7 downto 0);
        
        SpriteRAMAddress : in std_logic_vector(7 downto 0);
        SpriteRAMData_in : in std_logic_vector(7 downto 0);
        SpriteRAMData_out : out std_logic_vector(7 downto 0);
        SpriteRAMWriteEnable : in std_logic
        );
end component;

component TileFetcher is
	port	(
        CLK : in std_logic;
        CE : in std_logic;
        RSTN : in std_logic;
        
        HPOS : in unsigned(8 downto 0);
        VPOS : in unsigned(8 downto 0);
        
        TileColor : out unsigned(3 downto 0);
        
        VRAMAddress : out unsigned(13 downto 0);
        VRAMData : in std_logic_vector(7 downto 0)
		  
        );
end component;

	signal HSYNC_cnt : integer := 0;
	signal VSYNC_cnt : integer := 0;
	signal HPOS : integer;
	signal VPOS : integer;
	
	signal HPOS_u : unsigned(8 downto 0);
	signal VPOS_u : unsigned(8 downto 0);
	
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
	
	signal VRAMData : VRAMType := (others => "00000000");
	signal PaletteRAM : PaletteRAMType := (others => "UUUUUU");
	
	type SpriteMemDataType is array(255 downto 0) of std_logic_vector(7 downto 0);
	signal SpriteMemAddress : unsigned(7 downto 0);
	signal SpriteMemData : SpriteMemDataType := (others => (others => '0'));
	
	signal SpriteRAMAddress : std_logic_vector(7 downto 0);
	signal SpriteRAMData_in : std_logic_vector(7 downto 0);
	signal SpriteRAMData_out : std_logic_vector(7 downto 0);
	signal SpriteRAMWriteEnable : std_logic;
	
	signal TilePattern0 : std_logic_vector(15 downto 0);
	signal TilePattern1 : std_logic_vector(15 downto 0);
	signal TileAttribute : std_logic_vector(15 downto 0);
	
	
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
	
	
	signal SpriteColor : std_logic_vector(3 downto 0);
	signal SpriteOverflow : std_logic;
	signal BGTileName : unsigned(7 downto 0);
	
	signal TileColor : unsigned(3 downto 0);
	signal TileVRAMAddress : unsigned(13 downto 0);
begin

	CHR_Address <= PPU_Address;
	
	VBlank_n <= VBlankFlag nand Status_2000(7); -- Check on flag and VBlank Enable
	
	HPOS <= HSYNC_cnt - 42;
	VPOS <= VSYNC_cnt;
	
	HPOS_u <= to_unsigned(HPOS, 9);
	VPOS_u <= to_unsigned(VPOS, 9);
	
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
				attr_color := unsigned(TileAttribute(attr_pos + 1 downto attr_pos));
				
				--attr_color := unsigned(TilePipeline(0).attr(1 downto 0));
				bg_color := attr_color & TilePattern1(7 - HPOS mod 8) & TilePattern0(7 - HPOS mod 8);
				
				--FB_Color <= std_logic_vector(to_unsigned(HPOS / 16, FB_Color'length));
				FB_Color <= std_logic_vector(PaletteRAM(to_integer(bg_color)));
				--FB_Color <= std_logic_vector(PaletteRAM(to_integer(bg_color(1 downto 0))));
				
				--FB_Color <= std_logic_vector(to_unsigned(attr_pos, 6));
				
				--FB_Color <= "00" & TilePipeline(0).pattern1(HPOS mod 8) & TilePipeline(0).pattern0(HPOS mod 8) & "00";
				
				FB_Color <= std_logic_vector(PaletteRAM(to_integer(TileColor)));
				
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
						--Status_2000 <= Data_in_d;
						Status_2000 <= Data_in_d(7 downto 2) & "00";
					elsif Address = "001" then
						Status_2001 <= Data_in_d;
					elsif Address = "011" then
						SpriteMemAddress <= unsigned(Data_in_d);
					elsif Address = "100" then
						SpriteMemData(to_integer(SpriteMemAddress)) <= Data_in_d;
						SpriteMemAddress <= SpriteMemAddress + 1;
					elsif Address = "101" then
						if CPUPortDir = '1' then
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
					Data_out <= SpriteRAMData_out;
					SpriteRAMAddress <= std_logic_vector(unsigned(SpriteRAMAddress) + 1);
				elsif Address = "111" then
					Data_out <= PPU_Data_r;
					CPUVRAMRead <= '1';
				else
					Data_out <= (others => 'X'); -- This should be a write only register
				end if;
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
				--InternalAddress := PPU_Address;
				InternalAddress := TileVRAMAddress;
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
--	
--	SPRITE_LOOKUP : process (clk, rstn)
--	variable currentSprite : SpriteCacheEntry;
--	begin
--		if rstn = '0' then
--			--SpriteCache <= (others => (others => (others => '0')));
--			SpriteCounter <= 0;
--		elsif rising_edge(clk) and CE = '1' then
--			if VPOS = 0 and HPOS = 0 then
--				HitSpriteFlag <= '0';
--			end if;
--			if HPOS = -1 then
--				SpriteCounter <= 0;
--				SpritesFound <= 0;
--			elsif SpriteCounter < 64 and HPOS >= 0 and HPOS < 256 and VPOS >= 0 and VPOS < 240 then
--				if HPOS mod 2 = 0 then
--					currentSprite.y := unsigned(SpriteMemData(SpriteCounter * 4));
--					currentSprite.x := unsigned(SpriteMemData(SpriteCounter * 4 + 1));
--					currentSprite.pattern := unsigned(SpriteMemData(SpriteCounter * 4 + 2));
--					currentSprite.attr := unsigned(SpriteMemData(SpriteCounter * 4 + 3));
--				else
--					if currentSprite.y - VPOS < 8 and currentSprite.y - VPOS > 0 and SpritesFound < 8 then
--						SpriteCache(SpritesFound) <= currentSprite;
--						
--						SpritesFound <= SpritesFound + 1;
--						
--						if SpriteCounter = 0 then
--							HitSpriteFlag <= '1';
--						end if;
--					end if;
--					SpriteCounter <= SpriteCounter + 1;
--				end if;
--			end if;
--		end if;
--	end process;
	
	SPRITE_SEL : SpriteSelector
	port map (
		CLK => CLK,
		CE => CE,
		RSTN => RSTN,
		
		HPOS => HPOS_u,
		VPOS => VPOS_u,
		
		SpriteColor => SpriteColor,
		SpriteOverflow => SpriteOverflow,
		
--		VRAMAddress => VRAMAddress,
		VRAMData => PPU_Data_r,
		
		SpriteRAMAddress => SpriteRAMAddress,
		SpriteRAMData_in => SpriteRAMData_in,
		SpriteRAMData_out => SpriteRAMData_out,
		SpriteRAMWriteEnable => SpriteRAMWriteEnable
        );
		  
	TILE_FETCHER : TileFetcher
	port map (
		CLK => CLK,
		CE => CE,
		RSTN => RSTN,
		
		HPOS => HPOS_u,
		VPOS => VPOS_u,
		
      TileColor => TileColor,
		
		VRAMAddress => TileVRAMAddress,
		VRAMData => PPU_Data_r
	);

end arch;
