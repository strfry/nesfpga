
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

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

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
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

      -- insert stimulus here 

      wait;
   end process;

END;
