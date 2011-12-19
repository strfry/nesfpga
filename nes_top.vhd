--------------------------------------------------------------------------------
-- Entity: nes_top
-- Date:2011-10-21  
-- Author: jonathansieber     
--
-- Description ${cursor}
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


Library UNISIM;
use UNISIM.vcomponents.all;

use work.NES_Pack.all;

entity nes_top is
	port  (
		CLK : in std_logic;        -- input clock, 100 MHz.
		RSTN : in std_logic;
		
		--HDMICLK

		

         HDMIHSync : OUT  std_logic;

         HDMIVSync : OUT  std_logic;

         HDMIDE : OUT  std_logic;

         HDMICLKP : OUT  std_logic;

         HDMICLKN : OUT  std_logic;

         HDMID : OUT  std_logic_vector(11 downto 0);

         HDMISCL : INOUT  std_logic;

         HDMISDA : INOUT  std_logic;

         HDMIRSTN : OUT  std_logic

    --     LED : OUT  std_logic_vector(0 to 7);

      --   BTN : IN  std_logic_vector(0 to 1)
	);
end nes_top;

architecture arch of nes_top is



	signal DCM_CLK0 : std_logic;

	signal DCM_Reset : std_logic;

	signal DCM_Reset_cnt : unsigned(15 downto 0);

	
	signal NES_Clock : std_logic;
	signal TFT_Clock : std_logic;
	signal VBlank_NMI_n : std_logic;

	signal CPU_Address : std_logic_vector(15 downto 0);
	signal CPU_Data : std_logic_vector(7 downto 0);

	signal PPU_CPU_Data : std_logic_vector(7 downto 0); 
	signal CPU_RW : std_logic;
	signal CPU_PHI2 : std_logic; -- High when CPU_Data is valid

	signal CPU_PPU_CS_n : std_logic;



	signal PPU_FB_Address : std_logic_vector(15 downto 0);
	signal PPU_FB_Color : std_logic_vector(5 downto 0);
	signal PPU_FB_DE : std_logic;




	signal PRG_Data : std_logic_vector(7 downto 0);

	signal CPU_PRG_CS_n : std_logic;



	signal CHR_Address : unsigned(13 downto 0);
	signal CHR_Data : std_logic_vector(7 downto 0);


	signal HDMI_FB_Address : std_logic_vector(15 downto 0);
	signal HDMI_FB_Color : std_logic_vector(5 downto 0);

	--type fb_ram_type is array(0 to 256 * 224) of std_logic_vector(5 downto 0);

	type fb_ram_type is array(65535 downto 0) of std_logic_vector(5 downto 0);

	signal fb_ram : fb_ram_type := (others => "101010");

begin

	 

	 CPU_PPU_CS_n <= '0' when CPU_Address(15 downto 3) = "0010000000000" and CPU_PHI2 = '1' else '1';

	 CPU_PRG_CS_n <= '0' when CPU_Address(15) = '1' and CPU_PHI2 = '1' else '1';
    

	 DCM_WAIT : process(DCM_CLK0, RSTN)

	 begin

		if RSTN = '0' then

			DCM_Reset_cnt <= (others => '1');

			DCM_Reset <= '0';

		elsif rising_edge(DCM_CLK0) then

			if DCM_Reset_cnt = 0 then

				DCM_Reset <= '1';

			else

				DCM_Reset <= '0';

				DCM_Reset_cnt <= DCM_Reset_cnt - 1;

			end if;			

		end if;

	 end process;

	 
    process (CPU_RW, PPU_CPU_Data, PRG_Data, CPU_PPU_CS_n, CPU_PRG_CS_n, CPU_Address)
    begin
        if CPU_RW = '1' then

				if CPU_PPU_CS_n = '0' then
					CPU_Data <= PPU_CPU_Data;
				elsif	CPU_PRG_CS_n = '0' then
					CPU_Data <= PRG_Data;

				else
					CPU_Data <= (others => 'Z');

				end if;

		  else
				CPU_Data <= (others => 'Z');
        end if;
    end process; 
    
    process (Nes_Clock) 
    begin
        if rising_edge(Nes_Clock) then
            if PPU_FB_DE = '1' then
                fb_ram(to_integer(unsigned(PPU_FB_Address))) <= PPU_FB_Color;
            end if;
        end if;
    end process;

	 

	 process (TFT_Clock)
	 begin
		if rising_edge(TFT_Clock) then
--			if unsigned(HDMI_FB_Address) < 57344 then
				HDMI_FB_Color <= fb_ram(to_integer(unsigned(HDMI_FB_Address)));
--			else
--				HDMI_FB_Color <= (others => '0');
--			end if;
		end if;
	 end process;
    

    CPU: NES_2A03
    port map (
        Global_Clk => NES_Clock,
        Reset_N => DCM_Reset,
        NMI_N => VBlank_NMI_n,
        IRQ_N => '1',
        
        Data => CPU_Data,
        Address => CPU_Address,
        RW_10 => CPU_RW,
        
        PHI2 => CPU_PHI2,
        
        CStrobe => open,
        C1R_N => open,
        C2R_N => open,
        
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
        clk => NES_Clock,

		  rstn => DCM_Reset,
        ChipSelect_n => CPU_PPU_CS_n,
        ReadWrite => CPU_RW,
        Address => CPU_Address(2 downto 0),
        Data_in => CPU_Data,
        Data_out => PPU_CPU_Data,
        
        CHR_Address => CHR_Address,
        CHR_Data => CHR_Data,
        
        VBlank_n => VBlank_NMI_n,
        FB_Address => PPU_FB_Address,
        FB_Color => PPU_FB_Color,
        FB_DE => PPU_FB_DE
    );

	 

	Cartridge : CartridgeROM
	port map (
			--clk => CPU_PHI2,

			clk => NES_Clock,
			rstn => DCM_Reset,		 
			PRG_Address => CPU_Address(14 downto 0),
			PRG_Data => PRG_Data,
        
			CHR_Address => CHR_Address,
			CHR_Data => CHR_Data
	);

	

	HDMIOut : HDMIController

	port map (

		CLK => TFT_Clock,

		RSTN => DCM_Reset,

		CLK_25 => TFT_Clock,

		

		HDMIHSync => HDMIHSync,

		HDMIVSync => HDMIVSync,

		HDMIDE => HDMIDE,

		HDMICLKP => HDMICLKP,

		HDMICLKN => HDMICLKN,

		HDMID => HDMID,

		HDMISCL => HDMISCL,

		HDMISDA => HDMISDA,

		HDMIRSTN => HDMIRSTN,

		

		FB_Address => HDMI_FB_Address,

		FB_Data => HDMI_FB_Color

	);

	 

	DCM_BASE_inst : DCM_BASE
	generic map (
		CLKDV_DIVIDE => 4.0, -- Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5
									--   7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0
		CLKFX_DIVIDE => 9,   -- Can be any integer from 1 to 32
		CLKFX_MULTIPLY => 2, -- Can be any integer from 2 to 32
		CLKIN_DIVIDE_BY_2 => FALSE, -- TRUE/FALSE to enable CLKIN divide by two feature
		CLKIN_PERIOD => 10.0, -- Specify period of input clock in ns from 1.25 to 1000.00
		CLKOUT_PHASE_SHIFT => "NONE", -- Specify phase shift mode of NONE or FIXED
		CLK_FEEDBACK => "1X",         -- Specify clock feedback of NONE or 1X
		DCM_PERFORMANCE_MODE => "MAX_RANGE",   -- Can be MAX_SPEED or MAX_RANGE
		DESKEW_ADJUST => "SYSTEM_SYNCHRONOUS", -- SOURCE_SYNCHRONOUS, SYSTEM_SYNCHRONOUS or
															--   an integer from 0 to 15
		DFS_FREQUENCY_MODE => "LOW",   -- LOW or HIGH frequency mode for frequency synthesis
		DLL_FREQUENCY_MODE => "LOW",   -- LOW, HIGH, or HIGH_SER frequency mode for DLL
		DUTY_CYCLE_CORRECTION => TRUE, -- Duty cycle correction, TRUE or FALSE
		FACTORY_JF => X"F0F0",          -- FACTORY JF Values Suggested to be set to X"F0F0" 
		PHASE_SHIFT => 0, -- Amount of fixed phase shift from -255 to 1023
		STARTUP_WAIT => FALSE) -- Delay configuration DONE until DCM LOCK, TRUE/FALSE
	port map (
		CLK0 => DCM_CLK0,     -- 0 degree DCM CLK ouptput
		CLK180 => open,	    -- 180 degree DCM CLK output
		CLK270 => open,       -- 270 degree DCM CLK output
		CLK2X => open,        -- 2X DCM CLK output
		CLK2X180 => open,     -- 2X, 180 degree DCM CLK out
		CLK90 => open,        -- 90 degree DCM CLK output
		CLKDV => TFT_Clock,        -- Divided DCM CLK out (CLKDV_DIVIDE)
		CLKFX => NES_Clock,   -- DCM CLK synthesis out (M/D)
		CLKFX180 => open,     -- 180 degree CLK synthesis out
		LOCKED => open, -- DCM LOCK status output
		CLKFB => DCM_CLK0,        -- DCM clock feedback
		CLKIN => CLK,         -- Clock input (from IBUFG, BUFG or DCM)
		RST => "not"(RSTN)    -- DCM asynchronous reset input
	);


	process (VBlank_NMI_n)
		type IntegerFile is file of integer;
		file fblog : IntegerFile open write_mode is "foo.bar";
	begin
		if falling_edge(VBLank_NMI_n) then
			for i in 0 to 65535 loop
				--write(fblog, to_integer(fb_ram(0)));
				write(fblog, to_integer(unsigned(fb_ram(i))));
			end loop;
		end if;
	
	end process;

	
end arch;

