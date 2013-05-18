--------------------------------------------------------------------------------
-- Entity: CartridgeROM
-- Date:2011-10-25  
-- Author: jonathansieber     
--
-- Description ${cursor}
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

Library UNISIM;
use UNISIM.vcomponents.all;

entity CartridgeROM is
	port  (
		clk : in std_logic;        -- input clock, xx MHz.
		rstn : in std_logic;
		 
        PRG_Address : in std_logic_vector(14 downto 0);
        PRG_Data : out std_logic_vector(7 downto 0);
        
        CHR_Address : in unsigned(13 downto 0);
        CHR_Data : out std_logic_vector(7 downto 0)
	);
end CartridgeROM;


architecture arch of CartridgeROM is
	COMPONENT prg_rom_NESStress
	PORT (
		clka : IN STD_LOGIC;
		addra : IN STD_LOGIC_VECTOR(14 DOWNTO 0);
		douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
	END COMPONENT;

	COMPONENT chr_rom_NEStress
	PORT (
		clka : IN STD_LOGIC;
		addra : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
		douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
	END COMPONENT;
	
	COMPONENT prg_rom_smb
	PORT (
		clka : IN STD_LOGIC;
		addra : IN STD_LOGIC_VECTOR(14 DOWNTO 0);
		douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
	END COMPONENT;

	COMPONENT chr_rom_smb
	PORT (
		clka : IN STD_LOGIC;
		addra : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
		douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
	END COMPONENT;
begin
--
--prg : prg_rom_NESStress
--  PORT MAP (
--    clka => clk,
--    addra => PRG_Address,
--    douta => PRG_Data
--  );
--
--chr : chr_rom_NEStress
--  PORT MAP (
--    clka => clk,
--    addra => std_logic_vector(CHR_Address(12 downto 0)),
--    douta => CHR_Data
--  );
  
prg : prg_rom_smb
  PORT MAP (
    clka => clk,
    addra => PRG_Address,
    douta => PRG_Data
  );

chr : chr_rom_smb
  PORT MAP (
    clka => clk,
    addra => std_logic_vector(CHR_Address(12 downto 0)),
    douta => CHR_Data
  );

end arch;


