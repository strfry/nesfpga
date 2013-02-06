library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use STD.textio.all;

entity NES_Framebuffer_TB is
end entity;

architecture arch of NES_Framebuffer_TB is

  component NES_Mainboard is
	port (
    clk : in std_logic;        -- approximation to NES mainboard clock 21.47727
    rstn : in std_logic;
        
    -- Framebuffer output
    FB_Address : out unsigned(15 downto 0); -- linear index in 256x240 pixel framebuffer
    FB_Color : out std_logic_vector(5 downto 0); -- Palette index of current color
    FB_DE : out std_logic;    -- True when PPU is writing to the framebuffer
        
    -- Controller input
    Controller_Strobe : out std_logic; -- Set shift register in controller with current buttons
    Controller1_Clock : out std_logic; -- Shift register by one bit on falling edge
    Controller2_Clock : out std_logic; -- Shift register by one bit on falling edge
        
    Controller1_Data0_N : in std_logic; -- Shift register highest bit
    Controller1_Data1_N : in std_logic; -- Not connected in standard controllers
    Controller1_Data2_N : in std_logic; -- Not connected in standard controllers
        
    Controller2_Data0_N : in std_logic; -- Shift register highest bit
    Controller2_Data1_N : in std_logic; -- Not connected in standard controllers
    Controller2_Data2_N : in std_logic; -- Not connected in standard controllers
        
    PinWithoutSemicolon : out std_logic
	);
	end component;
	
	signal NES_Clock : std_logic;
	signal NES_Reset : std_logic;

	signal FB_Address : unsigned(15 downto 0);
	signal FB_Color : std_logic_vector(5 downto 0);
	signal FB_DE : std_logic;	
	
	signal Controller_Strobe : std_logic;
	signal Controller1_Clock : std_logic;
	signal Controller2_Clock : std_logic;
	
	signal Controller1_ShiftRegister : std_logic_vector(7 downto 0);
	
	constant fb_size : integer :=	340 * 261 - 1; 
  type fb_ram_type is array(fb_size downto 0) of std_logic_vector(5 downto 0);
  type FramebufferFileType is file of fb_ram_type;

	signal fb_ram : fb_ram_type := (others => "101010");
	
	signal FrameCount : integer := 0;
	
	constant CLK_period : time := 1 us / 21.47727;
	
begin
  
  uut : NES_Mainboard port map (
    clk => NES_Clock,
    rstn => NES_Reset,
    
    FB_Address => FB_Address,
    FB_Color => FB_Color,
    FB_DE => FB_DE,
    
    Controller_Strobe => Controller_Strobe,
    Controller1_Clock => Controller1_Clock,
    Controller2_Clock => Controller2_Clock,
    
    Controller1_Data0_N => Controller1_ShiftRegister(0),
    Controller1_Data1_N => '0',
    Controller1_Data2_N => '0',
    Controller2_Data0_N => '0',
    Controller2_Data1_N => '0',
    Controller2_Data2_N => '0',
    
    PinWithoutSemicolon => open
  );
  
  
  -- Clock process definitions
  CLK_process :process
  begin
	  NES_Clock <= '0';
		wait for CLK_period/2;
		NES_Clock <= '1';
		wait for CLK_period/2;
  end process;
 

   -- Stimulus process
  stim_proc: process
  begin		
	  NES_Reset <= '0';
    wait for 1 ms;	
		NES_Reset <= '1';
    wait;
  end process;
  
  CONTROLLER_INPUT: process (Controller_Strobe, Controller1_Clock)
  begin
    if falling_edge(Controller_Strobe) then
      case FrameCount is
        when 10 => 
--          Controller1_ShiftRegister <= "00000000";
          Controller1_ShiftRegister <= "11111011";
        when 13 => 
--          Controller1_ShiftRegister <= "00000000";
          Controller1_ShiftRegister <= "11111011";
        when 16 => 
--          Controller1_ShiftRegister <= "00000000";
          Controller1_ShiftRegister <= "11111110";
        when 35 =>
          Controller1_ShiftRegister <= "11111110";
        when 52 =>
          Controller1_ShiftRegister <= "11111110";
        when 70 =>
          Controller1_ShiftRegister <= "11111110";
        when others =>
          Controller1_ShiftRegister <= "11111111";
      end case;
    elsif Controller_Strobe = '0' and rising_edge(Controller1_Clock) then
      Controller1_ShiftRegister <= "1" & Controller1_ShiftRegister(7 downto 1);
    end if;
  end process;
  
  FB_WRITE_proc : process (NES_Clock) 
  variable v, h : integer;
  begin
    if rising_edge(Nes_Clock) then
      if FB_DE = '1' then
        -- fb_ram stores the full 340x261 range, but the PPU only outputs
        -- the visible range 256x240. For this reason, we recompute the address
        -- here:
        
        v := to_integer(FB_Address / 256);
        h := to_integer(FB_Address mod 256) + 42;
        
        fb_ram(v * 340 + h) <= FB_Color;
      end if;
    end if;
  end process;
  
  FB_DUMP_proc : process (FB_Address, FB_DE)
    file my_output : FramebufferFileType open WRITE_MODE is "fbdump_top.out";
    variable my_line : LINE;
    variable my_output_line : LINE;
  begin
    if rising_edge(FB_DE) and FB_Address = X"0000" then
      write(my_line, string'("writing file"));
      writeline(output, my_line);
      write(my_output, fb_ram);
      FrameCount <= FrameCount + 1;
    end if;
  end process;
	
end architecture arch;