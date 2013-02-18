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
use work.PPU_Pack.all;

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
        FB_Address : out unsigned(15 downto 0); -- linear index in 256x240 pixel framebuffer
        FB_Color : out std_logic_vector(5 downto 0); -- Palette index of current color
        FB_DE : out std_logic    -- True when PPU is writing to the framebuffer

	);
end NES_2C02;

architecture arch of NES_2C02 is


  -- Internal H/V Counters
	signal HSYNC_cnt : integer range 0 to 340 := 0;
	signal VSYNC_cnt : integer range 0 to 261 := 0;
	
	-- Internal H/V Counters with adjusted ranges
	signal HPOS : integer range -42 to 298;
	signal VPOS : integer range 0 to 261;
	

	signal CE_cnt : unsigned(1 downto 0) := "00";
	signal CE : std_logic;
	
	signal VBlankFlag : std_logic := '0';
	signal HitSpriteFlag : std_logic := '0';
	
	signal Status_2000 : std_logic_vector(7 downto 0) := "00000000";
	signal Status_2001 : std_logic_vector(7 downto 0) := "00000000";
		
	signal Data_in_d : std_logic_vector(7 downto 0) := "00000000";
	signal CPUPortDir : std_logic;
	
	signal ChipSelect_delay : std_logic;
	
	signal VerticalScrollOffset : unsigned(7 downto 0) := "00000000";
	signal HorizontalScrollOffset : unsigned(7 downto 0) := "00000000";
	
	-- Internal Muxer outputs for read access on the PPU Memory Bus
	signal PPU_Address : unsigned(13 downto 0);
	signal PPU_Data : std_logic_vector(7 downto 0);
	
	signal CPUVRAM_Address : unsigned(13 downto 0);
	signal CPUVRAM_WriteData : std_logic_vector(7 downto 0);
	signal CPUVRAM_Read : std_logic;
	signal CPUVRAM_Write : std_logic;
	
	type VRAMType is array(2047 downto 0) of std_logic_vector(7 downto 0);
	type PaletteRAMType is array(31 downto 0) of std_logic_vector(5 downto 0);
	
	signal VRAM : VRAMType := (others => "00000000");
	signal VRAM_Data : std_logic_vector(7 downto 0);
	
	        signal PaletteRAM : PaletteRAMType := (
                0 =>  "000000",
                1 =>  "000001",
                2 =>  "000010",
                3 =>  "000011",
                4 =>  "000100",
                5 =>  "000101",
                6 =>  "000110",
                7 =>  "000111",
                8 =>  "001000",
                9 =>  "001001",
                10 => "001010",
                11 => "001011",
                12 => "001100",
                13 => "001101",
                14 => "001110",
                15 => "001111",
                16 => "010000",
                17 => "010001",
                18 => "010010",
                19 => "010011",
                20 => "010100",
                21 => "010101",
                22 => "010110",
                23 => "010111",
                24 => "011000",
                25 => "011001",
                26 => "011010",
                27 => "011011",
                28 => "011100",
                29 => "011101",
                30 => "011110",
                31 => "011111"
--              others => "UUUUUU"
        );
        
  signal SpriteVRAM_Address : unsigned(13 downto 0);
	signal SpriteRAM_Address : unsigned(7 downto 0) := X"00";
	signal SpriteRAM_Data_in : std_logic_vector(7 downto 0);
	signal SpriteRAM_Data_out : std_logic_vector(7 downto 0);
	signal SpriteRAM_WriteEnable : std_logic;
	
	signal SpriteColor : unsigned(3 downto 0);
	signal SpriteForegroundPriority : std_logic;
	signal SpriteIsPrimary : std_logic;
	signal SpriteOverflowFlag : std_logic;
	
	
	signal TileVRAM_Address : unsigned(13 downto 0);
	
	signal TileColor : unsigned(3 downto 0);
	
begin

	CHR_Address <= PPU_Address;
	
	VBlank_n <= VBlankFlag nand Status_2000(7); -- Check on flag and VBlank Enable
	
	HPOS <= HSYNC_cnt - 42;
	VPOS <= VSYNC_cnt;
	
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
	variable color : integer;
	begin
		if rising_edge(clk) and CE = '1' then
		  FB_DE <= '0';
			if HPOS >= 0 and HPOS < 256 and VPOS >= 0 and VPOS < 240 then
			  
			  FB_DE <= '1';
			  FB_Address <= to_unsigned(HPOS + VPOS * 256, FB_Address'length);
		
				if (SpriteForegroundPriority = '1' or TileColor(1 downto 0) = "00") and SpriteColor(1 downto 0) /= "00" then
				  color := to_integer(SpriteColor) + 16;
				elsif TileColor(1 downto 0) /= "00" then
				  color := to_integer(TileColor);
				else
				  color := 16;
				end if;
				
				FB_Color <= PaletteRAM(color);

				
				--if SpritesFound > 0 then
				--	if SpriteCache(0).x - HPOS < 8 then FB_Color <= "101111"; end if;
				--end if;
				
				
				if VPOS >= 230 then
					FB_Color <= PaletteRAM(HPOS / 8);
				end if;
				
			else
			  FB_Color <= "000000";
			end if;
		end if;
	end process;
	
	
	CPU_PORT : process (clk)
	variable PPUDATA_read : std_logic_vector(7 downto 0);
	begin	
		if rising_edge(clk) then
		  if CE = '1' and ChipSelect_N = '1' then
		    if HPOS >= 0 and HPOS < 3 and VPOS = 0 then -- Start VBlank period
					VBlankFlag <= '1';
				elsif HPOS >= 0 and HPOS < 3 and VPOS = 20 then -- End VBlank Period
					VBlankFlag <= '0';
					HitSpriteFlag <= '0';
				end if;
				
				-- Hack: Increment sprite RAM address after write here, to avoid off-by-one condition
				if SpriteRAM_WriteEnable = '1' then
						SpriteRAM_Address <= SpriteRAM_Address + 1;
				end if;
								
    		  CPUVRAM_Write <= '0';
		    CPUVRAM_Read <= '0';
				SpriteRAM_WriteEnable <= '0';
		      
		    if CPUVRAM_Read = '1' or CPUVRAM_Write = '1' then
		      if (Status_2000(2) = '0') then
		        CPUVRAM_Address <= CPUVRAM_Address + 1;
		      else
		        CPUVRAM_Address <= CPUVRAM_Address + 32;
		      end if;
		      
		      PPUDATA_read := PPU_Data;
			  end if;
			  
			  -- Check for Sprite 0 collision
			  if TileColor(1 downto 0) /= "00" and SpriteColor(1 downto 0) /= "00" and SpriteIsPrimary = '1' then
			    HitSpriteFlag <= '1';
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
					  SpriteRAM_Address <= unsigned(Data_in_d);
					elsif Address = "100" then
						SpriteRAM_Data_in <= Data_in_d;
						SpriteRAM_WriteEnable <= '1';
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
							CPUVRAM_Address(13 downto 8) <= unsigned(Data_in_d(5 downto 0));
						else
							CPUVRAM_Address(7 downto 0) <= unsigned(Data_in_d);
					  end if;						
						CPUPortDir <= not CPUPortDir;
				  elsif Address = "111" then					  
					  CPUVRAM_Write <= '1';
					  CPUVRAM_WriteData <= Data_in_d;
					  					  
					  -- Palette RAM is not actual RAM, just directly accessed registers, so implement it here
					  if CPUVRAM_Address(13 downto 8) = X"3F" then
					    PaletteRAM(to_integer(CPUVRAM_Address(4 downto 0))) <= Data_in_d(5 downto 0);
						end if;
				  end if;
				elsif Address = "010" then
					VBlankFlag <= '0'; -- Reset flag at the end of read period
					CPUPortDir <= '0'; -- Reset 16 bit register selector
				end if;
		  elsif ChipSelect_delay = '1' and ChipSelect_n = '0' and ReadWrite = '1' then
				if Address = "000" then
					Data_out <= Status_2000;
			  elsif Address = "001" then
					Data_out <= Status_2001;
				elsif Address = "010" then
					Data_out <= (6 => HitSpriteFlag, 7 => VBlankFlag, others => '0');
					--Data_out <= (6 => HitSpriteFlag, 7 => '1', others => '0');
				elsif Address = "100" then
					Data_out <= SpriteRAM_Data_out;
					SpriteRAM_Address <= SpriteRAM_Address + 1;
				elsif Address = "111" then
				  Data_out <= PPUDATA_read;
				  CPUVRAM_Read <= '1';
				  if CPUVRAM_Address(13 downto 8) = X"3F" then
				    Data_out <= "00" & PaletteRAM(to_integer(CPUVRAM_Address(4 downto 0)));
				  end if;
				else
					Data_out <= (others => 'X'); -- This should be a write only register
				end if;
			end if;
		end if;
	end process;
	
	
	PPU_ADDRESS_MUXER : process (CPUVRAM_Read, CPUVRAM_Write, CPUVRAM_Address, TileVRAM_Address, HPOS)
	begin
		if CPUVRAM_Read = '1' then
      PPU_Address <= CPUVRAM_Address;
		elsif CPUVRAM_Write = '1' then
			PPU_Address <= CPUVRAM_Address;
		elsif HPOS >= -15 and HPOS < 256 then
			PPU_Address <= TileVRAM_Address;
		else
		  PPU_Address <= SpriteVRAM_Address;
		end if;
	end process;
	
	PPU_DATA_MUXER : process (PPU_Address, VRAM_Data, PaletteRAM, CHR_Data)
	begin	  
		-- The cartridge has tri-state access to the address lines A10/A11,
		-- so it can either provide additional 2k of SRAM, or tie them to 0
		-- to mirror the address range of the upper nametables to the lower ones
				
		-- Super Mario Brothers selects vertical mirroring (A11 tied down),
		-- so thats what we are doing here for now
	  if PPU_Address(13 downto 12) = "10" then -- VRAM
	    PPU_Data <= VRAM_Data;
		else
		  -- Default to external PPU Data
		  PPU_Data <= CHR_Data;
		end if; 
	end process;
	
	-- The nametable VRAM was an extern SRAM IC in the NES,
	-- here it is implemented internally with BRAM
	
	INTERNAL_VRAM : process (clk)
	begin
	  if rising_edge(clk) then
			if CE = '1' and CPUVRAM_Write = '1' and PPU_Address(13 downto 12) = "10" then
			  VRAM(to_integer(PPU_Address(10 downto 0))) <= CPUVRAM_WriteData;
			end if;
		  VRAM_Data <= VRAM(to_integer(PPU_Address(10 downto 0)));
	  end if;	  
  end process;
	
	SPRITE_SEL : SpriteSelector
	port map (
		CLK => CLK,
		CE => CE,
		RSTN => RSTN,
		
		HPOS => HPOS,
		VPOS => VPOS,
		
		PatternTableAddressOffset => Status_2000(3),
		
		SpriteColor => SpriteColor,
		SpriteForegroundPriority => SpriteForegroundPriority,
		SpriteIsPrimary => SpriteIsPrimary,
		
		SpriteOverflowFlag => SpriteOverflowFlag,
		
		VRAM_Address => SpriteVRAM_Address,
		VRAM_Data => PPU_Data,
	
		SpriteRAM_Address => SpriteRAM_Address,
		SpriteRAM_Data_in => SpriteRAM_Data_in,
		SpriteRAM_Data_out => SpriteRAM_Data_out,
		SpriteRAM_WriteEnable => SpriteRAM_WriteEnable
  );
		  
	TILE_FETCHER : TileFetcher
	port map (
		CLK => CLK,
		CE => CE,
		RSTN => RSTN,
		
		HPOS => HPOS,
		VPOS => VPOS,
		
    TileColor => TileColor,
		
		HorizontalScrollOffset => HorizontalScrollOffset,
		VerticalScrollOffset => VerticalScrollOffset,
		PatternTableAddressOffset => Status_2000(4),
		NameTableAddressOffset => Status_2000(1 downto 0),
		
		VRAM_Address => TileVRAM_Address,
		VRAM_Data => PPU_Data
	);

end arch;
