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

  type CHRRAMType is array(0 to 8191) of bit_vector(7 downto 0);

  impure function InitCHRRAMFromFile (RamFileName : in string) return CHRRAMType is
    FILE RamFile : text is in RamFileName;
    variable RamFileLine : line;
    variable RAM : CHRRAMType;
  begin
    for I in CHRRAMType'range loop
      readline (RamFile, RamFileLine);
      read (RamFileLine, RAM(I));
    end loop;
    return RAM;
  end function;

  signal CHRRAM : CHRRAMType := InitCHRRAMFromFile("roms/smb_chr.dat");
  
  type PRGRAMType is array(0 to 32767) of bit_vector(7 downto 0);

  impure function InitPRGRAMFromFile (RamFileName : in string) return PRGRAMType is
    FILE RamFile : text is in RamFileName;
    variable RamFileLine : line;
    variable RAM : PRGRAMType;
  begin
    for I in PRGRAMType'range loop
      readline (RamFile, RamFileLine);
      read (RamFileLine, RAM(I));
    end loop;
    return RAM;
  end function;

  signal PRGRAM : PRGRAMType := InitPRGRAMFromFile("roms/smb_prg.dat");

begin

  process (clk)
  begin
    if rising_edge(clk) then
      CHR_Data <= to_stdlogicvector(CHRRAM(to_integer(CHR_Address(12 downto 0))));
      
      PRG_Data <= to_stdlogicvector(PRGRAM(to_integer(unsigned(PRG_Address))));
    end if;
  end process;

end arch;


