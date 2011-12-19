
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SpriteSelector is
	port  (
        CLK : in std_logic;
        CE : in std_logic;
        RSTN : in std_logic;
        
        HPOS : in unsigned(8 downto 0);
        VPOS : in unsigned(8 downto 0);
        
        SpriteColor : out unsigned(3 downto 0);
        SpritePriority : out std_logic;
        SpriteOverflow : out std_logic;
        
        VRAMAddress : out unsigned(13 downto 0);
        VRAMData : in std_logic_vector(7 downto 0);
        
        SpriteRAMAddress : in std_logic_vector(7 downto 0);
        SpriteRAMData_in : in std_logic_vector(7 downto 0);
        SpriteRAMData_out : out std_logic_vector(7 downto 0);
        SpriteRAMWriteEnable : in std_logic;
        
        );
end SpriteSelector;


architecture arch of SpriteSelector is
    
   
begin
    PIXEL_MUX : process (CLK)
    variable colorBits : unsigned(1 downto 0);
    begin
        if rising_edge(CLK) and CE = '1' then
            for i in 7 downto 7 do
                if LineBuffer(i).x < 8 then
                    colorBits := LineBuffer(i).pattern0(LineBuffer(i).x) &  LineBuffer(i).pattern1(LineBuffer(i).x);
                    
                    if colorBits <> "00" then
                        SpriteColor <= LineBuffer(i).attr & colorBits;
                    end if;
                end if;
                LineBuffer(i).x <= LineBuffer(i).x - 1;
            loop;
        end if;
    end process:
    
    PATTERN_FETCH : process (CLK)
    begin
    end process:

    LOOKUP : process (CLK)
    variable i, ydiff : integer;
    variable currentSprite;
    begin
        if rising_edge(CLK) and CE = '1' then
            if HPOS = XX then
                LineBuffer <= (others => (others => (others => '0')));
                SpriteCounter <= 0;
            elsif HPOS > XX then
                i := HPOS mod 4;
                ydiff
                if SpriteRAM(i).y = VPOS 
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
