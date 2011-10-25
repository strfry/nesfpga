--------------------------------------------------------------------------------
-- Entity: CartridgeROM
-- Date:2011-10-25  
-- Author: jonathansieber     
--
-- Description ${cursor}
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

entity CartridgeROM is
	port  (
		clk : in std_logic;        -- input clock, xx MHz.
		 
        ProgramAddress : in std_logic_vector(14 downto 0);
        ProgramData : out std_logic_vector(7 downto 0);
        
        CharacterAddress : in std_logic_vector(14 downto 0);
        CharacterData : out std_logic_vector(7 downto 0)
	);
end CartridgeROM;

architecture arch of CartridgeROM is

begin



end arch;

