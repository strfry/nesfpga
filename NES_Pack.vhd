--------------------------------------------------------------------------------
-- Entity: NESPack
-- Date:2011-10-25  
-- Author: jonathansieber     
--
-- Description ${cursor}
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

package NES_Pack is
    
    component NES_2A03 is
        port (
            Global_Clk  : in std_logic;     --input clock signal from NES mobo crystal
            Reset_N         : in std_logic;     --External Reset
            NMI_N       : in std_logic;
            IRQ_N       : in std_logic;
            Data            : inout std_logic_vector(7 downto 0);
            Address         : buffer std_logic_vector(15 downto 0);
            RW_10           : buffer std_logic;     --low if writing, high if reading
            PHI1            : out std_logic;
            PHI2            : out std_logic;    --Clock Divider Output
            
            --Controller Outputs
            CStrobe : out std_logic;    --Controller Strobe Signal 
            C1R_N   : out std_logic;    --low when reading controller 1
            C2R_N   : out std_logic;    --low when reading controller 2
            
            --Audio Outputs
            A_Rectangle : out std_logic;    --Rectangle Wave Output (Mixed)
            A_Combined  : out std_logic;    --Triangle, Noise, And PCM (DPCM) Output
            
            --The following three signals represent the status of an internal register
            --  used in accessing the expansion port
            W_4016_1    : out std_logic;
            W_4016_2    : out std_logic;
            
            --Debugging
            ClockDividerTrigger : out std_logic;
            --LCycle : out std_logic_vector(2 downto 0);
            --MCycle : out std_logic_vector(2 downto 0);
            --InitialReset : out std_logic;
            AddOKDebug : out std_logic;
            ReadOKDebug : out std_logic;
            WriteOKDebug : out std_logic;
            SRAMChipSelect_NDebug : out std_logic;
            SRAMWriteEnable_NDebug : out std_logic;
            SRAMOutputEnable_NDebug :out std_logic;
            SRAMReading : out std_logic;
            SRAMWriting : out std_logic
        );
    end component;
    
    component NES_2C02 is
    port  (
        clk : in std_logic;        -- input clock, 5,37 MHz.
        -- rst : in std_logic;    -- the 2C02 does not have a reset pin, and the sync_n pin
                               -- seems to be unnecessary, as it is either hardwired to 1 or reset
        
        -- CPU Bus
        ChipSelect_n : in std_logic;
        ReadWrite : in std_logic; -- Write to PPU on 0
        Address : in std_logic_vector(2 downto 0);
        Data_in : in std_logic_vector(7 downto 0);
        Data_out : out std_logic_vector(7 downto 0);
        
        -- VRAM/VROM bus
        --foo
        
        VBlank_n : out std_logic; -- Tied to the CPU's Non-Maskable Interrupt (NMI)     
        
        -- Framebuffer output
        FB_Adress : out unsigned(15 downto 0); -- linear index in 256x240 pixel framebuffer
        FB_Color : out unsigned(5 downto 0); -- Palette index of current color
        FB_DE : out std_logic    -- True when PPU is writing to the framebuffer
    );
    end component;
end;
