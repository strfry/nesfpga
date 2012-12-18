
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;


use IEEE.std_logic_textio.all;
use STD.textio.all;

ENTITY PPU_tb IS
END PPU_tb;
 
ARCHITECTURE behavior OF PPU_tb IS 
    
    component NES_2C02 is
    port  (
        clk : in std_logic;        -- input clock, 5,37 MHz.
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
        FB_Address : out std_logic_vector(15 downto 0); -- linear index in 256x240 pixel framebuffer
        FB_Color : out std_logic_vector(5 downto 0); -- Palette index of current color
        FB_DE : out std_logic    -- True when PPU is writing to the framebuffer
    );
    end component;


	 component CartridgeROM is
	 port  (
			clk : in std_logic;        -- input clock, xx MHz.
			rstn : in std_logic;
			 
			PRG_Address : in std_logic_vector(14 downto 0);
			PRG_Data : out std_logic_vector(7 downto 0);
			  
			CHR_Address : in unsigned(13 downto 0);
			CHR_Data : out std_logic_vector(7 downto 0)
	);
	end component;
	
   --Inputs
   signal clk : std_logic := '0';
   signal rstn : std_logic := '0';
   signal ChipSelect_n : std_logic := '0';
   signal ReadWrite : std_logic := '0';
   signal Address : std_logic_vector(2 downto 0) := (others => '0');
   signal Data_in : std_logic_vector(7 downto 0) := (others => '0');
   signal CHR_Data : std_logic_vector(7 downto 0) := (others => '0');

 	--Outputs
   signal Data_out : std_logic_vector(7 downto 0);
   signal CHR_Address : unsigned(13 downto 0);
   signal VBlank_n : std_logic;
   signal FB_Address : std_logic_vector(15 downto 0);
   signal FB_Color : std_logic_vector(5 downto 0);
   signal FB_DE : std_logic;
   
 	 type fb_ram_type is array(65535 downto 0) of std_logic_vector(5 downto 0);
 	 
 	 signal fb_ram : fb_ram_type;

   -- Clock period definitions
   constant clk_period : time := 10 ns;
   
   type FramebufferFileType is file of fb_ram_type;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: NES_2C02 PORT MAP (
          clk => clk,
          rstn => rstn,
          ChipSelect_n => ChipSelect_n,
          ReadWrite => ReadWrite,
          Address => Address,
          Data_in => Data_in,
          Data_out => Data_out,
          CHR_Address => CHR_Address,
          CHR_Data => CHR_Data,
          VBlank_n => VBlank_n,
          FB_Address => FB_Address,
          FB_Color => FB_Color,
          FB_DE => FB_DE
        );

	mem: CartridgeROM
	port map (
		clk => clk,
		rstn => rstn,
		PRG_Address => (others => '0'),
		PRG_Data => open,
		CHR_Address => CHR_Address,
		CHR_Data => CHR_Data
	);
	
	  process (clk) 
    begin
        if rising_edge(clk) then
            if FB_DE = '1' then
                fb_ram(to_integer(unsigned(FB_Address))) <= FB_Color;
            end if;
        end if;
    end process;
    
    FB_DUMP: process (VBlank_n)
      file my_output : FramebufferFileType open WRITE_MODE is "file_io.out";
      -- above declaration should be in architecture declarations for multiple
      variable my_line : LINE;
      variable my_output_line : LINE;
    begin
      if falling_edge(VBlank_n) then
        write(my_line, string'("writing file"));
        writeline(output, my_line);
        write(my_output, fb_ram);
--        writeline(my_output, my_output_line);
      end if;
    end process;
    
   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
		rstn <= '0';
      wait for 100 ns;	
		rstn <= '1';

      wait for clk_period*10;
		
		-- Enable VBlank Interrupt in Register $2000
		Address <= "000";
		Data_in <= "10000000";
		ReadWrite <= '0';
		
      wait for clk_period*3;

		ChipSelect_n <= '1';
		
      wait for clk_period*3;
		ReadWrite <= '1';
      wait;
   end process;

END;
