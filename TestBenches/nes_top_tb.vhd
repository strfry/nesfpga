LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY nes_top_tb IS
END nes_top_tb;
 
ARCHITECTURE behavior OF nes_top_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT nes_top
    PORT(
         CLK : IN  std_logic;
         RSTN : IN  std_logic;
         HDMIHSync : OUT  std_logic;
         HDMIVSync : OUT  std_logic;
         HDMIDE : OUT  std_logic;
         HDMICLKP : OUT  std_logic;
         HDMICLKN : OUT  std_logic;
         HDMID : OUT  std_logic_vector(11 downto 0);
         HDMISCL : INOUT  std_logic;
         HDMISDA : INOUT  std_logic;
         HDMIRSTN : OUT  std_logic;
--         LED : OUT  std_logic_vector(0 to 7);
         BTN : IN  std_logic_vector(0 to 6)
        );
    END COMPONENT;
    

   --Inputs
   signal CLK : std_logic := '0';
   signal RSTN : std_logic := '0';
   signal BTN : std_logic_vector(0 to 6) := (others => '0');

	--BiDirs
   signal HDMISCL : std_logic;
   signal HDMISDA : std_logic;

 	--Outputs
   signal HDMIHSync : std_logic;
   signal HDMIVSync : std_logic;
   signal HDMIDE : std_logic;
   signal HDMICLKP : std_logic;
   signal HDMICLKN : std_logic;
   signal HDMID : std_logic_vector(11 downto 0);
   signal HDMIRSTN : std_logic;
   signal LED : std_logic_vector(0 to 7);

   -- Clock period definitions
   constant CLK_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: nes_top PORT MAP (
          CLK => CLK,
          RSTN => RSTN,
          HDMIHSync => HDMIHSync,
          HDMIVSync => HDMIVSync,
          HDMIDE => HDMIDE,
          HDMICLKP => HDMICLKP,
          HDMICLKN => HDMICLKN,
          HDMID => HDMID,
          HDMISCL => HDMISCL,
          HDMISDA => HDMISDA,
          HDMIRSTN => HDMIRSTN,
--          LED => LED,
          BTN => BTN
        );

   -- Clock process definitions
   CLK_process :process
   begin
		CLK <= '0';
		wait for CLK_period/2;
		CLK <= '1';
		wait for CLK_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
		RSTN <= '0';
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for CLK_period*10;
		
		RSTN <= '1';

      -- insert stimulus here 

      wait;
   end process;

END;
