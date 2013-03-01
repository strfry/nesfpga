
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.NES_Pack.all;

entity Genesys_NES is
  port (
    CLK  : in std_logic;                -- input clock, 100 MHz.
    RSTN : in std_logic;

    HDMIHSync : out   std_logic;
    HDMIVSync : out   std_logic;
    HDMIDE    : out   std_logic;
    HDMICLKP  : out   std_logic;
    HDMICLKN  : out   std_logic;
    HDMID     : out   std_logic_vector(11 downto 0);
    HDMISCL   : inout std_logic;
    HDMISDA   : inout std_logic;
    HDMIRSTN  : out   std_logic;

    BTN : in std_logic_vector(6 downto 0);
    SW  : in std_logic_vector(7 downto 0)

    );
end Genesys_NES;

architecture Behavioral of Genesys_NES is
  component NES_Mainboard is
    port (
      clk  : in std_logic;  -- approximation to NES mainboard clock 21.47727
      rstn : in std_logic;

      -- Framebuffer output
      FB_Address : out unsigned(15 downto 0);  -- linear index in 256x240 pixel framebuffer
      FB_Color   : out std_logic_vector(5 downto 0);  -- Palette index of current color
      FB_DE      : out std_logic;  -- True when PPU is writing to the framebuffer

      -- Controller input
      Controller_Strobe : out std_logic;  -- Set shift register in controller with current buttons
      Controller1_Clock : out std_logic;  -- Shift register by one bit on falling edge
      Controller2_Clock : out std_logic;  -- Shift register by one bit on falling edge

      Controller1_Data0_N : in std_logic;  -- Shift register highest bit
      Controller1_Data1_N : in std_logic;  -- Not connected in standard controllers
      Controller1_Data2_N : in std_logic;  -- Not connected in standard controllers

      Controller2_Data0_N : in std_logic;  -- Shift register highest bit
      Controller2_Data1_N : in std_logic;  -- Not connected in standard controllers
      Controller2_Data2_N : in std_logic;  -- Not connected in standard controllers

      PinWithoutSemicolon : out std_logic
      );
  end component;



  signal NES_Clock : std_logic;
  signal TFT_Clock : std_logic;         -- 25 MHz

  signal NES_Clock_cnt : unsigned(7 downto 0);
  signal TFT_Clock_cnt : unsigned(1 downto 0);

  signal FB_Address : unsigned(15 downto 0);
  signal FB_Color   : std_logic_vector(5 downto 0);
  signal FB_DE      : std_logic;

  signal HDMI_FB_Address : std_logic_vector(15 downto 0);
  signal HDMI_FB_Color   : std_logic_vector(5 downto 0);

  type fb_ram_type is array(65535 downto 0) of std_logic_vector(5 downto 0);
  type FramebufferFileType is file of fb_ram_type;

  signal fb_ram : fb_ram_type := (others => "101010");


  signal Controller_Strobe : std_logic;
  signal Controller1_Clock : std_logic;
  signal Controller2_Clock : std_logic;

  signal Controller1_ShiftRegister : std_logic_vector(7 downto 0);
begin

  TFT_Clock <= TFT_Clock_cnt(1);

  CLOCK_DIVIDER : process (CLK)
    variable ref : integer;
  begin
    if rising_edge(clk) then
      if RSTN = '0' then
        NES_Clock_cnt <= X"00";
        TFT_Clock_cnt <= "00";
        NES_Clock     <= '0';
      else
        ref := to_integer(unsigned(SW));
        if NES_Clock_cnt = ref then
          NES_Clock_cnt <= X"00";
          NES_Clock     <= not NES_Clock;
        else
          NES_Clock_cnt <= NES_Clock_cnt + 1;
        end if;

        TFT_Clock_cnt <= TFT_Clock_cnt + 1;
      end if;
    end if;
  end process;

  CONTROLLER_INPUT : process (NES_Clock)
    variable Controller1_Clock_delay : std_logic;
  begin
    if rising_edge(NES_Clock) then
      if Controller_Strobe = '1' then
        -- Order of NES Controller byte: RIGHT, LEFT, DOWN, UP, START, SELECT, B, A
        
        Controller1_ShiftRegister <= not BTN(3) & not BTN(5) & not BTN(4) & not BTN(2) & not BTN(6) & "1" & not BTN(1) & not BTN(0);
      elsif Controller1_Clock = '1' and Controller1_Clock_delay = '0' then  -- detect rising edge
        Controller1_ShiftRegister <= "1" & Controller1_ShiftRegister(7 downto 1);
      end if;

      Controller1_Clock_delay := Controller1_Clock;
    end if;
  end process;


  FRAMEBUFFER_READ : process (TFT_Clock)
  begin
    if rising_edge(TFT_Clock) then
      HDMI_FB_Color <= fb_ram(to_integer(unsigned(HDMI_FB_Address)));
    end if;
  end process;

  FRAMEBUFFER_WRITE : process (NES_Clock)
  begin
    if rising_edge(Nes_Clock) then
      if FB_DE = '1' then
        fb_ram(to_integer(unsigned(FB_Address))) <= FB_Color;
      end if;
    end if;
  end process;
  
  

  uut : NES_Mainboard port map (
    clk  => NES_Clock,
    rstn => RSTN,

    FB_Address => FB_Address,
    FB_Color   => FB_Color,
    FB_DE      => FB_DE,

    Controller_Strobe => Controller_Strobe,
    Controller1_Clock => Controller1_Clock,
    Controller2_Clock => Controller2_Clock,

    Controller1_Data0_N => Controller1_ShiftRegister(0),
    Controller1_Data1_N => '1',
    Controller1_Data2_N => '1',
    Controller2_Data0_N => '1',
    Controller2_Data1_N => '1',
    Controller2_Data2_N => '1',

    PinWithoutSemicolon => open
    );

  HDMIOut : HDMIController
    port map (
      CLK       => TFT_Clock,
      RSTN      => RSTN,
      CLK_25    => TFT_Clock,
      HDMIHSync => HDMIHSync,
      HDMIVSync => HDMIVSync,
      HDMIDE    => HDMIDE,
      HDMICLKP  => HDMICLKP,
      HDMICLKN  => HDMICLKN,
      HDMID     => HDMID,
      HDMISCL   => HDMISCL,
      HDMISDA   => HDMISDA,
      HDMIRSTN  => HDMIRSTN,

      FB_Address => HDMI_FB_Address,
      FB_Data    => HDMI_FB_Color

      );

end Behavioral;

