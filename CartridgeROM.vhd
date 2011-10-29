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
		 
        ProgramAddress : in std_logic_vector(14 downto 0);
        ProgramData : out std_logic_vector(7 downto 0);
        
        CharacterAddress : in std_logic_vector(14 downto 0);
        CharacterData : out std_logic_vector(7 downto 0)
	);
end CartridgeROM;

architecture arch of CartridgeROM is
	constant prg_size : integer := 32768;
	constant chr_size : integer := 8192;
	
--	constant prg_size : integer := 64;
	--constant chr_size : integer := 32;
	
   type prg_rom_type is array (prg_size - 1 downto 0) of bit_vector(7 downto 0);
   type chr_rom_type is array (chr_size - 1 downto 0) of bit_vector(7 downto 0);
	 
	impure function prg_load_file (filename : in string) return prg_rom_type is                                                   
		FILE rom_file : text is in filename;
		variable current_line : line;
		variable ret : prg_rom_type;
    begin                                                        
       for I in prg_rom_type'range loop                                  
           readline (rom_file, current_line);
           read (current_line, ret(I));                                  
       end loop;                                                    
       return ret;
    end function;  

	impure function chr_load_file (filename : in string) return chr_rom_type is                                                   
		FILE rom_file : text is in filename;
		variable current_line : line;
		variable ret : chr_rom_type;
    begin                                                        
       for I in chr_rom_type'range loop                                  
           readline (rom_file, current_line);
           read (current_line, ret(I));                                  
       end loop;                                                    
       return ret;
    end function;  	 


    
    signal prg_rom : prg_rom_type := prg_load_file("smb.prg");
    signal chr_rom : chr_rom_type := chr_load_file("smb.chr");
begin


				
    process (clk) begin
        if rising_edge(clk) then
				ProgramData <= to_stdlogicvector(prg_rom(to_integer(unsigned(ProgramAddress))));
				CharacterData <= to_stdlogicvector(chr_rom(to_integer(unsigned(CharacterAddress))));
        end if;
    end process;

end arch;

