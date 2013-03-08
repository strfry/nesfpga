library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package PPU_Pack is
  component TileFetcher
    port (
      CLK             : in  std_logic;
      CE              : in  std_logic;
      RSTN            : in  std_logic;
      Loopy_v         : in  unsigned(14 downto 0);
      FineXScrolling  : in  unsigned(2 downto 0);
      EnableRendering : in  std_logic;
      PatternTableAddressOffset : in std_logic;
      Fine_HPOS       : in integer range 0 to 7;
      VRAM_Address    : out unsigned(13 downto 0);
      VRAM_Data       : in  std_logic_vector(7 downto 0);
      TileColor       : out unsigned(3 downto 0));
  end component;

  component SpriteSelector is
  port (
    CLK : in std_logic;
    CE : in std_logic;
    RSTN : in std_logic;
       
    HPOS : in integer range 0 to 340;
    VPOS : in integer range 0 to 261;
    
		PatternTableAddressOffset : in std_logic;
    
    SpriteColor : out unsigned(3 downto 0);
    SpriteForegroundPriority : out std_logic;
    SpriteIsPrimary : out std_logic;
        
    SpriteOverflowFlag : out std_logic;
        
    VRAM_Address : out unsigned(13 downto 0);
    VRAM_Data : in std_logic_vector(7 downto 0);
        
    SpriteRAM_Address : in unsigned(7 downto 0);
    SpriteRAM_Data_in : in std_logic_vector(7 downto 0);
    SpriteRAM_Data_out : out std_logic_vector(7 downto 0);
    SpriteRAM_WriteEnable : in std_logic  
  );
end component;

component Loopy_Scrolling
  port (
    clk           : in     std_logic;
    CE            : in     std_logic;
    rst           : in     std_logic;
    Loopy_t       : in     unsigned(14 downto 0);
    Loopy_v       : out unsigned(14 downto 0);
    ResetXCounter : in     std_logic;
    ResetYCounter : in     std_logic;
    IncXScroll    : in     std_logic;
    IncYScroll    : in     std_logic;    
    LoadAddress   : in     std_logic;
    IncAddress    : in     std_logic;
    AddressStep   : in     std_logic);
end component;
end package;
