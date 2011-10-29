--------------------------------------------------------------------------------
-- Entity: NES_2C02
-- Date:2011-10-24  
-- Author: jonathansieber     
--
-- Description ${cursor}
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

entity NES_2C02 is
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
        PPU_Address : out std_logic_vector(14 downto 0);
        PPU_Data : in std_logic_vector(7 downto 0);
        
        VBlank_n : out std_logic; -- Tied to the CPU's Non-Maskable Interrupt (NMI)     
        
        -- Framebuffer output
        FB_Address : out std_logic_vector(15 downto 0); -- linear index in 256x240 pixel framebuffer
        FB_Color : out std_logic_vector(5 downto 0); -- Palette index of current color
        FB_DE : out std_logic    -- True when PPU is writing to the framebuffer
	);
end NES_2C02;

architecture arch of NES_2C02 is

begin

	PPU_Address <= (others => '0');

end arch;

