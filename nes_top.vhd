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
		clk : in std_logic;        -- input clock, xx MHz.
		rstn : in std_logic;
		
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

    signal NES_CLK_cnt : unsigned(1 downto 0) := "00";

    signal NES_Clk : std_logic;
    signal VBlank_NMI_n : std_logic;
    
    signal CPU_Address : std_logic_vector(15 downto 0);
    signal CPU_Data : std_logic_vector(7 downto 0);
   
    signal CPU_PPU_Data : std_logic_vector(7 downto 0); 
    signal PPU_CPU_Data : std_logic_vector(7 downto 0); 
    signal CPU_RW : std_logic;
	 signal CPU_PPU_CS_n : std_logic;
    
    
    signal PPU_Address : std_logic_vector(14 downto 0);
    signal PPU_Data : std_logic_vector(7 downto 0);
    -- signal PPU_RW : std_logic;
    

    signal PPU_FB_Address : std_logic_vector(15 downto 0);
    signal PPU_FB_Color : std_logic_vector(5 downto 0);
    signal PPU_FB_DE : std_logic;
	 
	 
    signal PRG_Data : std_logic_vector(7 downto 0);
    signal CHR_Data : std_logic_vector(7 downto 0);
   
    
    signal HDMI_FB_Address : std_logic_vector(15 downto 0);
    signal HDMI_FB_Color : std_logic_vector(5 downto 0);
    
    --type fb_ram_type is array(0 to 256 * 224) of std_logic_vector(5 downto 0);
	 type fb_ram_type is array(0 to 256 * 224) of std_logic_vector(5 downto 0);
    
    signal fb_ram : fb_ram_type := (others => "101010");

begin
	 NES_Clk <= NES_CLK_cnt(1);
	 
	 process (CLK)
	 begin
		  if rising_edge(CLK) then
			   NES_CLK_cnt <= NES_CLK_cnt + 1;
		  end if;
	 end process;

	 CPU_PPU_CS_n <= '0' when CPU_Address(15 downto 3) = "0010000000000" else '1';
    
    process (CPU_RW, PPU_CPU_Data, PRG_Data)
    begin
        if CPU_RW = '1' then
				if CPU_PPU_CS_n = '0' then
					CPU_Data <= PPU_CPU_Data;
				elsif	CPU_Address(15) = '1'  then
					CPU_Data <= PRG_Data;
				else
					CPU_Data <= (others => 'Z');
				end if;
		  else
				CPU_Data <= (others => 'Z');
        end if;
    end process; 
    
    process (Nes_Clk) 
    begin
        if rising_edge(Nes_Clk) then
            if PPU_FB_DE = '1' then
                fb_ram(to_integer(unsigned(PPU_FB_Address))) <= PPU_FB_Color;
            end if;
        end if;
    end process;
	 
	 process (CLK)
	 begin
		if rising_edge(CLK) then
--			if unsigned(HDMI_FB_Address) < 57344 then
				HDMI_FB_Color <= fb_ram(to_integer(unsigned(HDMI_FB_Address)));
--			else
--				HDMI_FB_Color <= (others => '0');
--			end if;
		end if;
	 end process;
    

    CPU: NES_2A03
    port map (
        Global_Clk => NES_Clk,
        Reset_N => rstn,
        NMI_N => VBlank_NMI_n,
        IRQ_N => '1',
        
        Data => CPU_Data,
        Address => CPU_Address,
        RW_10 => CPU_RW,
        
        PHI1 => open,
        PHI2 => open,
        
        CStrobe => open,
        C1R_N => open,
        C2R_N => open,
        
        A_Rectangle => open,
        A_Combined => open,
        
        W_4016_1 => open,
        W_4016_2 => open,
        
        ClockDividerTrigger => open,
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
        clk => NES_Clk,
        ChipSelect_n => CPU_PPU_CS_n,
        ReadWrite => CPU_RW,
        Address => CPU_Address(2 downto 0),
        Data_in => CPU_Data,
        Data_out => CPU_PPU_Data,
        
        PPU_Address => PPU_Address,
        PPU_Data => PPU_Data,
        
        VBlank_n => VBlank_NMI_n,
        FB_Address => PPU_FB_Address,
        FB_Color => PPU_FB_Color,
        FB_DE => PPU_FB_DE
    );
	 
	Cartridge : CartridgeROM
	port map (
			clk => NES_Clk,
			rstn => rstn,		 
			ProgramAddress => CPU_Address(14 downto 0),
			ProgramData => PRG_Data,
        
			CharacterAddress => PPU_Address(14 downto 0),
			CharacterData => CHR_Data
	);
	
	HDMIOut : HDMIController
	port map (
		CLK => CLK,
		RSTN => rstn,
		CLK_25 => NES_CLK_cnt(1),
		
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
	 
	
	
end arch;

