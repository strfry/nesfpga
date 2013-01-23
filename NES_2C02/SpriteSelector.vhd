
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
    
		PatternTableAddressOffset : in std_logic;
    
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
	
	type SpriteRAMType is array(255 downto 0) of std_logic_vector(7 downto 0);
	signal SpriteRAM : SpriteRAMType := (
	   0 => X"30", 1 => "11111111", 2 => "11111111", 3 => X"30",
	   others => "00000000");
	
	signal CurrentSpriteIndex : integer range 0 to 63;
	signal NumSpritesFound : integer range 0 to 7;
   
begin
  
  SPRITE_RAM_PORT_A : process (clk)
  begin
    if rising_edge(clk) and CE = '1' then
      SpriteRAM_Data_out <= SpriteRAM(to_integer(SpriteRAM_Address));
      
      if (SpriteRAM_WriteEnable = '1') then
        SpriteRAM(to_integer(SpriteRAM_Address)) <= SpriteRAM_Data_in;
      end if;
    end if;
  end process;
  
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
      if sprite.x = 0 then
        patternColor := sprite.pattern0(0) & sprite.pattern1(0);
        
        if patternColor /= "00" then
          SpriteColor <= unsigned(sprite.attr & patternColor);
          SpriteForegroundPriority <= sprite.foreground;
          SpriteIsPrimary <= sprite.primary;
        end if;
      end if;
    end loop;
  end process;

    
  	SPRITE_LOOKUP : process (clk, rstn)
	   variable currentSprite : SpriteLineEntry;
	   variable currentSpriteYPOS : unsigned(7 downto 0);
  	begin
		if rstn = '0' then
			--SpriteCache <= (others => (others => (others => '0')));
			CurrentSpriteIndex <= 0;
		elsif rising_edge(clk) and CE = '1' then
		  for i in 7 downto 0 loop
		    if SpriteLineBuffer(i).x > 0 then
		      SpriteLineBuffer(i).x <= SpriteLineBuffer(i).x - 1;
		    else
		      SpriteLineBuffer(i).pattern0 <= SpriteLineBuffer(i).pattern0 srl 1;
		      SpriteLineBuffer(i).pattern1 <= SpriteLineBuffer(i).pattern1 srl 1;
		    end if;
		  end loop;
		  
			if VPOS = 0 and HPOS = 0 then
			  SpriteOverflowFlag <= '0';
			elsif HPOS = -1 then
			  CurrentSpriteIndex <= 0;
				NumSpritesFound <= 0;
        SpriteLineBuffer <= (others => (primary => '0', foreground => '0', attr => "00", others => "00000000"));
			elsif CurrentSpriteIndex < 63 and HPOS >= 0 and HPOS < 256 and VPOS >= 0 and VPOS < 240 then
				if HPOS mod 2 = 0 then
					currentSpriteYPOS := unsigned(SpriteRAM(CurrentSpriteIndex * 4));
					currentSprite.x := unsigned(SpriteRAM(CurrentSpriteIndex * 4 + 3));
					currentSprite.pattern0 := "11111111";
					currentSprite.pattern1 := "10101010";
					currentSprite.attr := "11";
					currentSprite.primary := '1';
					currentSprite.foreground := '1';
					--currentSprite.pattern0 := unsigned(SpriteRAM(CurrentSpriteIndex * 4 + 1));
					--currentSprite.pattern1 := unsigned(SpriteRAM(CurrentSpriteIndex * 4 + 2));
					--currentSprite.attr := unsigned(SpriteRAM(CurrentSpriteIndex * 4 + 3));
					
				else
					if currentSpriteYPOS - VPOS < 8 and currentSpriteYPOS - VPOS > 0 then
					  if NumSpritesFound < 8 then
					    SpriteLineBuffer(NumSpritesFound) <= currentSprite;
						  NumSpritesFound <= NumSpritesFound + 1;
						else
						  SpriteOverflowFlag <= '1';
						end if;
					end if;
					CurrentSpriteIndex <= CurrentSpriteIndex + 1;
				end if;
			end if;
		end if;
	end process;
end arch;
