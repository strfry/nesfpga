
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SpriteSelector is
  port (
    CLK : in std_logic;
    CE : in std_logic;
    RSTN : in std_logic;
        
    HPOS : in integer;
    VPOS : in integer;
    
    -- Selector output         
    SpriteColor : out unsigned(3 downto 0); -- Current Sprite Palette Index, after selecting         
    SpriteForegroundPriority : out std_logic; -- When '0', Sprite is only drawn when background is transparent ("00" Color)
    SpriteIsPrimary : out std_logic; -- Is '1' when the current output results from object #0, used for collision detection flag
        
    SpriteOverflowFlag : out std_logic; -- When more than 8 Sprites are detected on a scanline, this flag is set until the next VBlank period
        
    VRAM_Address : out unsigned(13 downto 0);
    VRAM_Data : in std_logic_vector(7 downto 0);
        
    SpriteRAM_Address : in unsigned(7 downto 0);
    SpriteRAM_Data_in : in std_logic_vector(7 downto 0);
    SpriteRAM_Data_out : out std_logic_vector(7 downto 0);
    SpriteRAM_WriteEnable : in std_logic        
  );
end SpriteSelector;


architecture arch of SpriteSelector is
	
	type SpriteLineEntry is record
		x : unsigned(7 downto 0);
		pattern0 : unsigned(7 downto 0);
		pattern1 : unsigned(7 downto 0);
		attr : unsigned(1 downto 0);
		primary : std_logic;
		foreground : std_logic;
	end record;
	
	type SpriteLineBufferType is array(7 downto 0) of SpriteLineEntry;
	signal SpriteLineBuffer : SpriteLineBufferType;
   
begin
  
  -- The Line Buffer contains up to 8 sprites, select the first one with non-zero color
  PIXEL_MUX : process (SpriteLineBuffer)
  variable sprite : SpriteLineEntry;
  variable xpos : integer;
  variable patternColor : unsigned(1 downto 0);
  begin
    SpriteColor <= "0000";
    SpriteForegroundPriority <= '0';
    SpriteIsPrimary <= '0';
    
    for i in 7 downto 0 loop -- Loop backwards to prioritize the first entry, as it is written last
      sprite := SpriteLineBuffer(i);
      xpos := to_integer(sprite.x);
      if xpos < 8 then
        patternColor := sprite.pattern0(xpos mod 8) & sprite.pattern1(xpos mod 8);
        
        if patternColor /= "00" then
          SpriteColor <= unsigned(sprite.attr & patternColor);
          SpriteForegroundPriority <= sprite.foreground;
          SpriteIsPrimary <= sprite.primary;
        end if;
      end if;
    end loop;
  end process;
  
  DUMMY_SPRITES : process (clk)
  begin
    if rising_edge(clk) and CE = '1' then
      if HPOS = 0 then
        SpriteLineBuffer <= (others => (primary => '0', foreground => '0', attr => "00", others => "00000000"));
      else
        for i in 7 downto 0 loop
          SpriteLineBuffer(i).x <= SpriteLineBuffer(i).x - 1;
        end loop; 
      end if;
      if VPOS >= 54 and VPOS < 62 and HPOS = 1 then
        SpriteLineBuffer(0).x <= to_unsigned(160, 8);
        SpriteLineBuffer(0).pattern0 <= "01010101";
        SpriteLineBuffer(0).pattern1 <= "11100011";
        SpriteLineBuffer(0).attr <= "00";
        SpriteLineBuffer(0).primary <= '1';
        SpriteLineBuffer(0).foreground <= '1';
      end if;
      
      
    end if;
  end process;
    
    
    LOOKUP : process (CLK)
    variable i, ydiff : integer;
    --variable currentSprite;
    begin
        if rising_edge(CLK) and CE = '1' then
            if HPOS = 0 then
--                SpriteLineBuffer <= (others => (primary => '0', foreground => '0', attr => (others => '0'), others => (others => '0')));
--                SpriteCounter <= 0;
--            elsif HPOS > XX then
--                i := HPOS mod 4;
                --if SpriteRAM(i).y = VPOS 
            end if;
        end if;
    end process;
    
--    	SPRITE_LOOKUP : process (clk, rstn)
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
--	
--		    elsif Prefetch_XPOS >= 256 and Prefetch_XPOS < 288 and Prefetch_YPOS >= 0 and Prefetch_YPOS < 240 then
--		    
--		        if Status_2000(5) = '1' then
--				    address := 4096;
--			    end if;
--		        case Prefetch_XPOS mod 8 then -- Original PPU reuses the tile fetching state machine, so do here
--		            when 4 =>
--		                currentSprite <= SpriteCache(Prefetch_XPOS - 260 / 8)<
--    		            -- Compute Sprite number implicitly from XPOS
--	    	            PPU_Address <= to_unsigned(address + 16 * currentSprite.name + currentSprite mod 8); 
--	    	        when 6 =>
--	    	            SpriteCache(Prefetch_XPOS - 260 / 8).pattern0 <= PPU_Data_r:
--	    	            PPU_Address <= to_unsigned(address + 16 * currentSprite.name + currentSprite mod 8 + 8);
--	    	        when 0 =>
--	    	            SpriteCache(Prefetch_XPOS - 260 / 8).pattern1 <= PPU_Data_r;
--	    	    end case;
--			end if;
--    
end arch;
