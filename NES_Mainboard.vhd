library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.NES_Pack.all;

entity NES_Mainboard is
	port  (
        clk : in std_logic;        -- approximation to NES mainboard clock 21.47727 MHz
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
end NES_Mainboard;

architecture arch of NES_Mainboard is
  
  -- CPU Interrupt connected to PPU
  signal VBlank_NMI_n : std_logic;
  
  -- CPU Bus
  
	signal CPU_Address : std_logic_vector(15 downto 0);
	signal CPU_Data : std_logic_vector(7 downto 0);
	signal CPU_RW : std_logic;
	signal CPU_PHI2 : std_logic; -- High when CPU_Data is valid
	
	-- CPU Bus slave ports
	
	signal PPU_CPU_Data : std_logic_vector(7 downto 0); 
	signal PRG_Data : std_logic_vector(7 downto 0);
	signal CPU_PPU_CS_n : std_logic;
	
	-- ChipSelect lines
	signal CPU_PRG_CS_n : std_logic;

  -- PPU Memory Bus
	signal CHR_Address : unsigned(13 downto 0);
	signal CHR_Data : std_logic_vector(7 downto 0);
	
	signal CPU_Controller1Read_N : std_logic;
	signal CPU_Controller2Read_N : std_logic;
  
begin
 
  -- Access PPU in memory range 0x2000 to 0x2007
  CPU_PPU_CS_n <= '0' when CPU_Address(15 downto 3) = "0010000000000" and CPU_PHI2 = '1' else '1';
	 
	-- Access Program ROM in range 0x8000 to 0xFFFF
  CPU_PRG_CS_n <= '0' when CPU_Address(15) = '1' and CPU_PHI2 = '1' else '1';
  
  -- Output inverting buffer is controlled by read access on reg $4016, e.g. Controller1Read_N
  Controller1_Clock <= not CPU_PHI2 when CPU_Controller1Read_N = '0' else '1';
  
  CPU_BUS_MUX : process(CPU_RW, PPU_CPU_Data, PRG_Data, CPU_PPU_CS_n, CPU_PRG_CS_n, CPU_Address, CPU_Controller1Read_N, CPU_Controller2Read_N)
  begin
    if CPU_RW = '1' then
		  if CPU_PPU_CS_n = '0' then
			  CPU_Data <= PPU_CPU_Data;
			elsif	CPU_PRG_CS_n = '0' then
				CPU_Data <= PRG_Data;
			elsif CPU_Controller1Read_N = '0' then
				CPU_Data <= "01000" & not Controller1_Data2_N & not Controller1_Data1_N & not Controller1_Data0_N;
			elsif CPU_Controller2Read_N = '0' then
				CPU_Data <= "01000" & not Controller2_Data2_N & not Controller2_Data1_N & not Controller2_Data0_N;
			else
				CPU_Data <= (others => 'Z');
		  end if;
		else
			CPU_Data <= (others => 'Z');
    end if;
  end process;
    
  
  CPU: NES_2A03
  port map (
    Global_Clk => clk,
    Reset_N => rstn,
    NMI_N => VBlank_NMI_n,
    IRQ_N => '1',
        
    Data => CPU_Data,
    Address => CPU_Address,
    RW_10 => CPU_RW,
        
    PHI2 => CPU_PHI2,
        
    CStrobe => Controller_Strobe,
    C1R_N => CPU_Controller1Read_N,
    C2R_N => CPU_Controller2Read_N,
        
    A_Rectangle => open,
    A_Combined => open,
        
    W_4016_1 => open,
    W_4016_2 => open,
        
    AddOKDebug => open,
    ReadOKDebug => open,
    WriteOKDebug => open,
    SRAMChipSelect_NDebug => open,
    SRAMWriteEnable_NDebug => open,
    SRAMOutputEnable_NDebug => open,
    SRAMReading => open,
    SRAMWriting => open
);
    
  PPU : NES_2C02
  port map (
    clk => clk,
		rstn => rstn,
		
    ChipSelect_n => CPU_PPU_CS_n,
    ReadWrite => CPU_RW,
    Address => CPU_Address(2 downto 0),
    Data_in => CPU_Data,
    Data_out => PPU_CPU_Data,
        
    CHR_Address => CHR_Address,
    CHR_Data => CHR_Data,
        
    VBlank_n => VBlank_NMI_n,
    
    FB_Address => FB_Address,
    FB_Color => FB_Color,
    FB_DE => FB_DE
  );

	Cartridge : CartridgeROM
	port map (
		clk => clk,
		rstn => rstn,		 
		PRG_Address => CPU_Address(14 downto 0),
		PRG_Data => PRG_Data,   
		CHR_Address => CHR_Address,
		CHR_Data => CHR_Data
	);
  
end architecture;
