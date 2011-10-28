--------------------------------------------------------------------------------
-- Entity: nes_top
-- Date:2011-10-21  
-- Author: jonathansieber     
--
-- Description ${cursor}
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.NES_Pack.all;

entity nes_top is
	port  (
		clk : in std_logic;        -- input clock, xx MHz.
		Reset_n : in std_logic
	);
end nes_top;

architecture arch of nes_top is

    signal NES_Clk : std_logic;
    signal VBlank_NMI_n : std_logic;
    
    signal CPU_Address : std_logic_vector(15 downto 0);
    signal CPU_Data : std_logic_vector(7 downto 0);
   
    signal CPU_PPU_Data : std_logic_vector(7 downto 0); 
    signal PPU_CS_n : std_logic;

begin

    PPU_CS_n <= '0' when CPU_Address(15 downto 3) = "0010000000000" else '1';
    
    process (CPU_RW, PPU_CS_n)
    begin
        if CPU_RW = '1' and PPU_CS_n = '0' then
            CPU_Data <= PPU_CPU_Data;
        else 
            CPU_Data <= (others => "Z");
        end if;
    end process; 

    CPU: NES_2A03
    port map (
        Global_Clk => NES_Clk,
        Reset_N => Reset_n,
        NMI_N => VBlank_NMI_n,
        IRQ_N => "1",
        
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
        Clk => NES_Clk,
        ChipSelect_n => PPU_CS_n,
        ReadWrite => CPU_RW,
        Address => CPU_Address,
        Data_in => CPU_Data,
        Data_out => CPU_PPU_Data,
        
        -- VRAM/VROM bus
        --foo
        
        VBlank_n => VBlank_NMI_n,
        FB_Address => FB_Address,
        FB_Color => FB_Color,
        FB_DE => FB_DE
    );

end arch;

