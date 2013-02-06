 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SpriteSelector is
  port (
    CLK : in std_logic;
    CE : in std_logic;
    RSTN : in std_logic;
        
    HPOS : in integer range -42 to 298;
    VPOS : in integer range 0 to 261;
    
		PatternTableAddressOffset : in std_logic;
    
    -- Selector output         
    SpriteColor : out unsigned(3 downto 0); -- Palette index of sprite at current VPOS/HPOS pixel position
    SpriteForegroundPriority : out std_logic; -- When '0', Sprite is only drawn when background is transparent ("00" Color)
    SpriteIsPrimary : out std_logic; -- Is '1' when the current output results from object #0, used for collision detection flag
        
    SpriteOverflowFlag : out std_logic; -- When more than 8 Sprites are detected on a scanline, this flag is set until the next VBlank period
        
    VRAM_Address : out unsigned(13 downto 0) := (others => '0');
    VRAM_Data : in std_logic_vector(7 downto 0);
        
    SpriteRAM_Address : in unsigned(7 downto 0);
    SpriteRAM_Data_in : in std_logic_vector(7 downto 0);
    SpriteRAM_Data_out : out std_logic_vector(7 downto 0);
    SpriteRAM_WriteEnable : in std_logic        
  );
end SpriteSelector;


architecture arch of SpriteSelector is
  
  -- Sprite RAM, also called (primary) OAM (Object Attribute Memory) is organized in 4 bytes per sprite,
  -- so 64 Sprites totalling 256 bytes can be described at a time.
  -- Memory layout of a Sprite Entry:
  -- RAM(SpriteNum * 4 + 0) = Y position, evaluated one scanline before the sprite is rendered
  -- RAM(SpriteNum * 4 + 1) = Tile Index
  -- RAM(SpriteNum * 4 + 2) = (7 => Y-Flip, 6 => X-Flip, 5 => BGPriority, (1 downto 0) => ColorPalette)
  -- RAM(SpriteNum * 4 + 3) = X position
  
    
  -- Each scanline, while memory access is reserved to the Background Tile Pipeline, the Sprite Selector
  -- selects up to 8 sprites from the OAM to be drawn in the next scanline and stores the necessary
  -- information in the "sprite temporary buffer".
  --
  -- After this period, the Sprite Selector gains read access to the PPU Memory bus and reads the
  -- corresponding tile patterns and writes them to the "secondary" OAM.
  
  
  -- The TempLineBuffer stores the result of the sprite evaluation phase. The MEMFETCH process
  -- reads 2 bytes from the Pattern Table, optionally flips them, and writes them to the Secondary OAM
  -- along with the remaining attributes.
  
  type TempLineBufferEntry is record
		patternIndex : unsigned(7 downto 0);
		ydiff : unsigned(7 downto 0);
		x : unsigned(7 downto 0);
		palette : unsigned(1 downto 0);
		xflip : std_logic;		
		foreground : std_logic;
		primary : std_logic;
  end record;
  
  constant TempLineBufferDefault : TempLineBufferEntry := (
    patternIndex => X"00", ydiff => X"FF", x => X"00",
    palette => "00", others => '0'
  );
  
	type TempLineBufferType is array(7 downto 0) of TempLineBufferEntry;
  signal TempLineBuffer : TempLineBufferType := (others => TempLineBufferDefault);
    
  
  -- This Datatype	corresponds to the "secondary OAM"
	type LineBufferEntry is record
		x : unsigned(7 downto 0);
		pattern0 : unsigned(7 downto 0);
		pattern1 : unsigned(7 downto 0);
		palette : unsigned(1 downto 0);
		foreground : std_logic;
		primary : std_logic;
	end record;
  
  constant LineBufferDefault : LineBufferEntry := (
    x => X"00", pattern0 => X"00", pattern1 => X"00",
    palette => "00", foreground => '0', primary => '0'
  );
	
	type LineBufferType is array(7 downto 0) of LineBufferEntry;
	signal SpriteLineBuffer : LineBufferType := (others => LineBufferDefault);
	
	
	type SpriteRAMType is array(255 downto 0) of std_logic_vector(7 downto 0);
	signal SpriteRAM : SpriteRAMType := (
	   0 => X"30", 1 => X"23", 2 => "11111111", 3 => X"30",
	   4 => X"30", 5 => X"33", 6 => "11111111", 7 => X"50",
	   8 => X"50", 9 => X"25", 10 => "11111111", 11 => X"50",
	   12 => X"70", 13 => X"55", 14 => "11111111", 16 => X"30",
	   others => X"FF");
	
	signal NumSpritesFound : integer range 0 to 8 := 0;
	
	-- reverse Function used to implement the X-Flip feature
	function reverse(p: unsigned) return unsigned is
    variable temp: unsigned(p'reverse_range);
    variable result: unsigned(p'range);
  begin
    for i in p'range loop
      temp(i) := p(i);
  end loop; 
    result := temp;
    return result;
  end;
   
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
  PIXEL_MUX : process (SpriteLineBuffer, HPOS)
  variable sprite : LineBufferEntry;
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
        patternColor := sprite.pattern1(0) & sprite.pattern0(0);
        
        if patternColor /= "00" then
          SpriteColor <= unsigned(sprite.palette & patternColor);
          SpriteForegroundPriority <= sprite.foreground;
          SpriteIsPrimary <= sprite.primary;
        end if;
      end if;
    end loop;
  end process;
  
    
  SPRITE_LOOKUP : process (clk, rstn)
	   variable attributeByte : std_logic_vector(7 downto 0);
	   variable CurrentSpriteIndex : integer;
  	begin
		if rstn = '0' then
			--SpriteCache <= (others => (others => (others => '0')));
			--CurrentSpriteIndex <= 0;
		elsif rising_edge(clk) and CE = '1' then
		  
			if VPOS = 0 and HPOS = 0 then
			  SpriteOverflowFlag <= '0';
			end if;
			
			if HPOS = -1 then
				NumSpritesFound <= 0;
        TempLineBuffer <= (others => TempLineBufferDefault);
			  CurrentSpriteIndex := 0;
			elsif HPOS >= 0 and HPOS < 256 and VPOS >= 0 and VPOS < 240 and NumSpritesFound < 8 then
			  -- Sprite Lookup phase (8 out of 64 selection)
			  
			  CurrentSpriteIndex := HPOS / 4;
			  
			  case HPOS mod 4 is
			    when 0 =>
			      TempLineBuffer(NumSpritesFound).ydiff <= VPOS - unsigned(SpriteRAM(CurrentSpriteIndex * 4));
			    when 1 =>
			      if TempLineBuffer(NumSpritesFound).ydiff < 8 then
			        TempLineBuffer(NumSpritesFound).patternIndex <= unsigned(SpriteRAM(CurrentSpriteIndex * 4 + 1));
			      end if;
			    when 2 =>
			      if TempLineBuffer(NumSpritesFound).ydiff < 8 then
			        attributeByte := SpriteRAM(CurrentSpriteIndex * 4 + 2);
			        TempLineBuffer(NumSpritesFound).palette <= unsigned(attributeByte(1 downto 0));
			        TempLineBuffer(NumSpritesFound).foreground <= attributeByte(5);
  			        if CurrentSpriteIndex = 0 then
  			          TempLineBuffer(NumSpritesFound).primary <= '1';
			        end if;			          
			      end if;
			    when 3 =>
			      if TempLineBuffer(NumSpritesFound).ydiff < 8 then
			        TempLineBuffer(NumSpritesFound).x <= unsigned(SpriteRAM(CurrentSpriteIndex * 4 + 3));
			        NumSpritesFound <= NumSpritesFound + 1;
			        --CurrentSpriteIndex <= CurrentSpriteIndex + 1;
			      end if;
			    when others =>
		    end case;
		    
			end if;
		end if;
	end process;
	
	
	SPRITE_MEMFETCH : process (clk)
	variable currentSprite : integer;
	variable patternAddress : unsigned(13 downto 0);
	variable fetchedByte : unsigned(7 downto 0);
	begin
	  if rising_edge(clk) and CE = '1' then
	    if HPOS >= 0 and HPOS < 256 then
		    for i in 7 downto 0 loop
		      if SpriteLineBuffer(i).x > 0 then
		        SpriteLineBuffer(i).x <= SpriteLineBuffer(i).x - 1;
		      else
		        SpriteLineBuffer(i).pattern0 <= SpriteLineBuffer(i).pattern0 srl 1;
		        SpriteLineBuffer(i).pattern1 <= SpriteLineBuffer(i).pattern1 srl 1;
		      end if;
		    end loop;
		  elsif HPOS >= 256 and HPOS < 288 then
		    currentSprite := (HPOS - 256) / 4;
		    patternAddress := "0" & PatternTableAddressOffset &
		      TempLineBuffer(currentSprite).patternIndex & (TempLineBuffer(currentSprite).ydiff(3 downto 0));
		      
		    if currentSprite < NumSpritesFound then
		      case HPOS mod 4 is
		        when 0 =>
		          VRAM_Address <= patternAddress;
		        when 1 => 
		          fetchedByte := unsigned(VRAM_Data);
		          if TempLineBuffer(currentSprite).xflip = '0' then
		            fetchedByte := reverse(fetchedByte);
		          end if;
		          
		          SpriteLineBuffer(currentSprite).pattern0 <= fetchedByte;
		          
		          VRAM_Address <= patternAddress + 8;
		        when 2 =>		          
		          fetchedByte := unsigned(VRAM_Data);
		          if TempLineBuffer(currentSprite).xflip = '0' then
		            fetchedByte := reverse(fetchedByte);
		          end if;
		          
		          SpriteLineBuffer(currentSprite).pattern1 <= fetchedByte;
		          
		          
		          SpriteLineBuffer(currentSprite).x <= TempLineBuffer(currentSprite).x;
		          SpriteLineBuffer(currentSprite).palette <= TempLineBuffer(currentSprite).palette;
		          SpriteLineBuffer(currentSprite).primary <= TempLineBuffer(currentSprite).primary;
		          SpriteLineBuffer(currentSprite).foreground <= TempLineBuffer(currentSprite).foreground;
		          
		        when others =>
		      end case;
		    end if;
		    		  
		  end if;
	    
    end if;
  end process;
end arch;
