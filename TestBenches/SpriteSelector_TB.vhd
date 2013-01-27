LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

use STD.textio.ALL;

use work.NES_Pack.all;
 
ENTITY SpriteSelector_TB IS
END SpriteSelector_TB;
 
ARCHITECTURE behavior OF SpriteSelector_TB IS 
 
   COMPONENT SpriteSelector
   PORT(
     CLK : IN  std_logic;
     CE : IN  std_logic;
     RSTN : IN  std_logic;
     HPOS : IN  integer;
     VPOS : IN  integer;
     PatternTableAddressOffset : IN  std_logic;
     SpriteColor : OUT  unsigned(3 downto 0);
     SpriteForegroundPriority : OUT  std_logic;
     SpriteIsPrimary : OUT  std_logic;
     SpriteOverflowFlag : OUT  std_logic;
     VRAM_Address : OUT  unsigned(13 downto 0);
     VRAM_Data : IN  std_logic_vector(7 downto 0);
     SpriteRAM_Address : IN  unsigned(7 downto 0);
     SpriteRAM_Data_in : IN  std_logic_vector(7 downto 0);
     SpriteRAM_Data_out : OUT  std_logic_vector(7 downto 0);
     SpriteRAM_WriteEnable : IN  std_logic
     );
   END COMPONENT;
      

  --Inputs
  signal PatternTableAddressOffset : std_logic := '0';
  signal VRAM_Data : std_logic_vector(7 downto 0) := (others => '0');
  signal SpriteRAM_Address : unsigned(7 downto 0) := (others => '0');
  signal SpriteRAM_Data_in : std_logic_vector(7 downto 0) := (others => '0');
  signal SpriteRAM_WriteEnable : std_logic := '0';

   --Outputs
  signal SpriteColor : unsigned(3 downto 0);
  signal SpriteForegroundPriority : std_logic;
  signal SpriteIsPrimary : std_logic;
  signal SpriteOverflowFlag : std_logic;
  signal VRAM_Address : unsigned(13 downto 0);
  signal SpriteRAM_Data_out : std_logic_vector(7 downto 0);

  -- Clock period definitions
  constant CLK_period : time := 10 ns;
  
  constant fb_size : integer :=	340 * 261 - 1; 
  type fb_ram_type is array(fb_size downto 0) of std_logic_vector(5 downto 0);
  type FramebufferFileType is file of fb_ram_type;
	signal fb_ram : fb_ram_type := (others => "101010");
	

  signal CLK : std_logic := '0';
  signal CE : std_logic := '0';
  signal RSTN : std_logic := '0';
  
  signal HPOS : integer range -42 to 298; -- negative values mark the HBlank period
  signal VPOS : integer range 0 to 261; -- 240 to 261 is the VBlank period
  
  signal CE_cnt : integer := 0;
 
BEGIN

  CE <= '1' when CE_cnt = 0 else '0';
  
  CLK_proc : process
  begin
    CLK <= '0';
    wait for CLK_period / 2;
    CLK <= '1';
    wait for CLK_period / 2;
  end process;
  
  process (clk)
  begin
    if rising_edge(clk) then
      if CE_cnt = 3 then
        CE_cnt <= 0;
      else
        CE_cnt <= CE_cnt + 1;
      end if;
    end if;
  end process;
 
  -- Instantiate the Unit Under Test (UUT)
  uut: SpriteSelector PORT MAP (
    CLK => CLK,
    CE => CE,
    RSTN => RSTN,
    HPOS => HPOS,
    VPOS => VPOS,
    PatternTableAddressOffset => PatternTableAddressOffset,
    SpriteColor => SpriteColor,
    SpriteForegroundPriority => SpriteForegroundPriority,
    SpriteIsPrimary => SpriteIsPrimary,
    SpriteOverflowFlag => SpriteOverflowFlag,
    VRAM_Address => VRAM_Address,
    VRAM_Data => VRAM_Data,
    SpriteRAM_Address => SpriteRAM_Address,
    SpriteRAM_Data_in => SpriteRAM_Data_in,
    SpriteRAM_Data_out => SpriteRAM_Data_out,
    SpriteRAM_WriteEnable => SpriteRAM_WriteEnable
  );
    
  Cartridge : CartridgeROM
  port map (
    clk => clk,
    rstn => rstn,     
    PRG_Address => (others => '0'),
    PRG_Data => open,   
    CHR_Address => VRAM_Address,
    CHR_Data => VRAM_Data
  );
  
  process (clk)
  begin
    if rising_edge(clk) and CE = '1' then
      if RSTN = '0' then
        HPOS <= -42;
        VPOS <= 0;
      else        
        if HPOS = 297 then
          HPOS <= -42;
          if VPOS = 260 then
            VPOS <= 0;
          else
            VPOS <= VPOS + 1;
          end if;
        else
          HPOS <= HPOS + 1;
        end if;
      end if;
    end if;
  end process;

  -- Stimulus process
  stim_proc: process
  begin    
    SpriteRAM_Address <= (others => '0');
    SpriteRAM_Data_in <= (others => '0');
    SpriteRAM_WriteEnable <= '0';
  
    RSTN <= '0';
    wait for 100 ns;  

    wait for CLK_period*10;

    
    RSTN <= '1';

    SpriteRAM_WriteEnable <= '1';

    for i in 0 to 63 loop
      SpriteRAM_Address	<= to_unsigned(i, 8);
      case i mod 4 is
        when 0 =>
          SpriteRAM_Data_in <= std_logic_vector(to_unsigned(40 + (i / 8) * 8, 8));
        when 1 =>
          SpriteRAM_Data_in <= std_logic_vector(to_unsigned(i / 4, 8));
--          SpriteRAM_Data_in <= X"00";
        when 2 =>
          SpriteRAM_Data_in <= "11111111";
        when 3 =>
          SpriteRAM_Data_in <= std_logic_vector(to_unsigned(30 + ((i / 4) mod 2) * 8 , 8));
        when others =>
      end case;
      wait for CLK_period * 4;
    end loop;
    SpriteRAM_WriteEnable <= '0';
        
    wait;
  end process;
  
  FB_WRITE_proc : process (clk) 
  variable fbaddr : integer;
  begin
    if rising_edge(clk) and CE = '1' then
      fbaddr := (HPOS + 42) + VPOS * 340;
        fb_ram(fbaddr) <= "00" & std_logic_vector(SpriteColor);

	-- Draw a border for the visible part of the screen
        if HPOS = -1 or HPOS = 256 or VPOS = 240 then
          fb_ram(fbaddr) <= "111010";
        end if;
    end if;
  end process;
  
  FB_DUMP_proc : process (clk)
    file my_output : FramebufferFileType open WRITE_MODE is "spritetb.out";
    variable my_line : LINE;
    variable my_output_line : LINE;
  begin
    if rising_edge(clk) and HPOS = 297 and VPOS = 260 then
      write(my_line, string'("writing file"));
      writeline(output, my_line);
      write(my_output, fb_ram);
    end if;
  end process;

END;
