-- Wrapper module for AC97 output from PCM lines
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

use work.Spar6_Parts.all;

entity ac97_output is
  port ( 
    CLK : in std_logic; -- 100 MHz Clock
    RSTN : in std_logic;
    
    -- AC97 Ports
      
    BITCLK : in  STD_LOGIC;
    AUDSDI : in  STD_LOGIC;
    AUDSDO : out  STD_LOGIC;
    AUDSYNC : out  STD_LOGIC;
    AUDRST : out  STD_LOGIC;

    -- Asynchronous PCM Input
    PCM_in_left : in std_logic_vector(15 downto 0);
    PCM_in_right: in std_logic_vector(15 downto	0)
	 );
end ac97_output;

-- ///////////////////////////////////////////////
-- //                ATTENTION!!!               //
-- // - - - - - - - - - - - - - - - - - - - - - //
-- //                                           //
-- //   The following code is copy-pasted crap  //
-- //                                           //
-- //           (In your own interest)          //
-- //                DO NOT READ!!!             //
-- ///////////////////////////////////////////////

architecture Behavioral of ac97_output is

	signal L_bus, R_bus, L_bus_out, R_bus_out : std_logic_vector(17 downto 0);	
	signal cmd_addr : std_logic_vector(7 downto 0);
	signal cmd_data : std_logic_vector(15 downto 0);
	signal ready : std_logic;
	signal latching_cmd : std_logic;
  
  constant VOLUME : std_logic_vector(4 downto 0) := "01011";
  constant SOURCE : std_logic_vector(2 downto 0) := "000";
  
begin
	-- INSTANTIATE BOTH THE MAIN DRIVER AND AC97 CHIP CONFIGURATION STATE-MACHINE 
	-------------------------------------------------------------------------------
	ac97_cont0 : entity work.ac97(arch)
		port map(n_reset => rstn, clk => clk, ac97_sdata_out => AUDSDO, ac97_sdata_in => AUDSDI, latching_cmd => latching_cmd ,
			ac97_sync => AUDSYNC, ac97_bitclk => BITCLK, ac97_n_reset => AUDRST, ac97_ready_sig => ready,
			L_out => L_bus, R_out => R_bus, L_in => L_bus_out, R_in => R_bus_out, cmd_addr => cmd_addr, cmd_data => cmd_data);
  
   ac97cmd_cont0 : entity work.ac97cmd(arch)
		port map (clk => clk, ac97_ready_sig => ready, cmd_addr => cmd_addr, cmd_data => cmd_data, volume => VOLUME, 
			source => SOURCE, latching_cmd => latching_cmd);  
	 
	--  Latch output back into input for Talkthrough testing
	--  this process can be replaced with a user component for signal processing 
	-------------------------------------------------------------------------------
  
	process ( clk, rstn, L_bus_out, R_bus_out, PCM_in_left, PCM_in_right)
	begin
		if (clk'event and clk = '1') then
			if rstn = '0' then
				L_bus <= (others => '0');
				R_bus <= (others => '0');
			elsif(ready = '1') then
				L_bus <= std_logic_vector(PCM_in_left) & "00";
				R_bus <= std_logic_vector(PCM_in_right) & "00";
			end if;
		end if;
	end process;

end Behavioral;


