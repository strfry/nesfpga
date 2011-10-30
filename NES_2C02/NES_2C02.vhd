--------------------------------------------------------------------------------
-- Entity: NES_2C02
-- Date:2011-10-24  
-- Author: jonathansieber     
--
-- Description ${cursor}
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity NES_2C02 is
	port  (
        clk : in std_logic;        -- approximation to NES mainboard clock 21.47727
        rstn : in std_logic;
        
        -- CPU Bus
        ChipSelect_n : in std_logic;
        ReadWrite : in std_logic; -- Write to PPU on 0
        Address : in std_logic_vector(2 downto 0);
        Data_in : in std_logic_vector(7 downto 0);
        Data_out : out std_logic_vector(7 downto 0);
        
        -- VRAM/VROM bus
        CHR_Address : buffer unsigned(13 downto 0);
        CHR_Data : in std_logic_vector(7 downto 0);
        
        VBlank_n : out std_logic; -- Tied to the CPU's Non-Maskable Interrupt (NMI)     
        
        -- Framebuffer output
        FB_Address : out std_logic_vector(15 downto 0); -- linear index in 256x240 pixel framebuffer
        FB_Color : out std_logic_vector(5 downto 0); -- Palette index of current color
        FB_DE : out std_logic    -- True when PPU is writing to the framebuffer
	);
end NES_2C02;

architecture arch of NES_2C02 is

	signal HSYNC_cnt : integer := 0;
	signal VSYNC_cnt : integer := 0;
	signal HPOS : integer;
	signal VPOS : integer;
	
	signal CE_cnt : unsigned(1 downto 0) := "00";
	signal CE : std_logic;
	
	signal VBlankFlag : std_logic := '0';
	signal HitSpriteFlag : std_logic := '0';
	
	signal Status_2000 : std_logic_vector(7 downto 0) := "00000000";
	signal Status_2001 : std_logic_vector(7 downto 0) := "00000000";
	
	type SpriteMemDataType is array(255 downto 0) of std_logic_vector(7 downto 0);
	signal SpriteMemAddress : unsigned(7 downto 0);
	signal SpriteMemData : SpriteMemDataType;
	
	signal CPUPortDir : std_logic;
	
	signal VerticalScrollOffset : unsigned(7 downto 0);
	signal HorizontalScrollOffset : unsigned(7 downto 0);
	
	signal PPU_Address : unsigned(13 downto 0);
	signal PPU_Data_r : std_logic_vector(7 downto 0);
	signal PPU_Data_w : std_logic_vector(7 downto 0);
	signal PPU_ReadWrite : std_logic; -- Read on 1, write on 0
	signal PPU_ReadWrite_delay : std_logic; -- Used for 2-Cycle memory access
--	signal VRAMData_in : std_logic_vector(7 downto 0);
--	signal VRAMData_out : std_logic_vector(7 downto 0);
	
	
	signal CPUVRAMAddress : unsigned(13 downto 0);
	signal CPUVRAMRead : std_logic;
	signal CPUVRAMWrite : std_logic;
	
	type VRAMType is array(2047 downto 0) of std_logic_vector(7 downto 0);
	type PaletteRAMType is array(31 downto 0) of std_logic_vector(7 downto 0);
	
	signal VRAMData : VRAMType;
	signal PaletteRAM : PaletteRAMType;
	
	type BackgroundTile is
		record
			name : std_logic_vector(7 downto 0);
			attr : std_logic_vector(7 downto 0);
			pattern0 : std_logic_vector(7 downto 0);
			pattern1 : std_logic_vector(7 downto 0);
	end record;
	
	type BackgroundTilePipelineType is array (0 to 3) of BackgroundTile;
	
	signal TilePipeline : BackgroundTilePipelineType;
begin

	VBlank_n <= VBlankFlag nand Status_2000(7); -- Check on flag and VBlank Enable
	HPOS <= HSYNC_cnt - 42;
	VPOS <= VSYNC_cnt - 20;
	
	CE <= '1' when CE_cnt = 0 else '0';
	
	process (clk)
	begin
		if rising_edge(clk) then
			CE_cnt <= CE_cnt + 1;
		end if;
	end process;
	
	
	process (clk)
	begin
		if rising_edge(clk) and CE = '1' then
			if HSYNC_cnt < 341 - 1 then
				HSYNC_cnt <= HSYNC_cnt + 1;
			else
				HSYNC_cnt <= 0;
				if VSYNC_cnt < 262 - 1 then
					VSYNC_cnt <= VSYNC_cnt + 1;
				else
					VSYNC_cnt <= 0;
				end if;
			end if;
		end if;
	end process;
	
	
	process (clk)
	begin
		if rising_edge(clk) and CE = '1' then
			if HPOS = 0 and VPOS = 0 then -- Start VBlank period
				VBlankFlag <= '1';
			elsif HPOS = 0 and VPOS = 20 then -- End VBlank Period
				VBlankFlag <= '0';
			elsif ChipSelect_n = '0' and ReadWrite = '1' and Address = "010" then
				VBlankFlag <= '0';
			end if;
			
			if HPOS >= 0 and HPOS < 256 and VPOS >= 0 and VPOS < 240 then
				FB_DE <= '1';
				FB_Address <= std_logic_vector(to_unsigned(VPOS * 256 + HPOS, FB_Address'length));
				
				
				--FB_Color <= std_logic_vector(to_unsigned(HPOS / 16, FB_Color'length));
				FB_Color <= Status_2001(7 downto 2);
			else
				FB_DE <= '0';
			end if;
		end if;
	end process;
	
	
	CPU_PORT : process (clk)
	begin
		if rising_edge(clk) and ChipSelect_n = '0' then
			
			CPUVRAMWrite <= '0';
			CPUVRAMRead <= '0';
		
			if ReadWrite = '0' then
				if Address = "000" then
					Status_2000 <= Data_in;
				elsif Address = "001" then
					Status_2001 <= Data_in;
				elsif Address = "011" then
					SpriteMemAddress <= unsigned(Data_in);
				elsif Address = "100" then
					SpriteMemData(to_integer(SpriteMemAddress)) <= Data_in;
					SpriteMemAddress <= SpriteMemAddress + 1;
				elsif Address = "101" then
					if CPUPortDir = '0' then
						if unsigned(Data_in) <= 239 then
							VerticalScrollOffset <= unsigned(Data_in);
						end if;
					else
						HorizontalScrollOffset <= unsigned(Data_in);
					end if;
					
					CPUPortDir <= not CPUPortDir;
				elsif Address = "110" then
					if CPUPortDir = '0' then
						CPUVRAMAddress(7 downto 0) <= unsigned(Data_in);
					else
						CPUVRAMAddress(13 downto 8) <= unsigned(Data_in(5 downto 0));
					end if;
					CPUPortDir <= not CPUPortDir;
				elsif Address = "111" then
					CPUVRAMWrite <= '1';
					PPU_Data_w <= Data_in;
					if (Status_2000(2) = '0') then
						CPUVRAMAddress <= CPUVRAMAddress + 1;
					else
						CPUVRAMAddress <= CPUVRAMAddress + 32;
					end if;
				end if;
			else
				if Address = "000" then
					Data_out <= Status_2000;
				elsif Address = "001" then
					Data_out <= Status_2001;
				elsif Address = "010" then
					Data_out <= (6 => HitSpriteFlag, 7 => VBlankFlag, others => '0');
					CPUPortDir <= '0';
				elsif Address = "100" then
					Data_out <= SpriteMemData(to_integer(SpriteMemAddress));
					SpriteMemAddress <= SpriteMemAddress + 1;
				elsif Address = "111" then
					Data_out <= PPU_Data_r;
					CPUVRAMRead <= '1';
					if (Status_2000(2) = '0') then
						CPUVRAMAddress <= CPUVRAMAddress + 1;
					else
						CPUVRAMAddress <= CPUVRAMAddress + 32;
					end if;
				else
					Data_out <= (others => 'X'); -- This should be a write only register
				end if;
			end if;
		end if;
	end process;
	
	process(clk)
	variable address : integer;
	begin
		if rising_edge(clk) and CE = '1' then
			address := 0;
			
			PPU_ReadWrite <= '1';
			PPU_Address <= (others => '0');
			
			if HPOS < 256 then
				case HPOS mod 8 is
					when 0 =>
						if Status_2000(4) = '1' then
							address := 4096;
						end if;
						
						address := address + HPOS / 8 + VPOS / 8 * 32;
						PPU_Address <= to_unsigned(address, PPU_Address'length);
						TilePipeline(0 to 1) <= TilePipeline(1 to 2);
	--				when 1 =>
					when others =>
						
				end case;
			end if;
--				elsif HPOS mod 4 = 1 then
--					address := 4096 when Status_2000(4) = '1' else 0;
---					address := offset + HPOS / 8 + VPOS / 8 * 32;
--					PPU_Address <= address;
					
		
		
		
		end if;
	end process;
	
	RAM_ACCESS : process (clk)
	begin
		if rstn = '0' then
			CHR_Address <= (others => '0');
		elsif rising_edge(clk) and CE = '1' then
			
			-- The 2C02 addresses the PPU memory bus with an 8 bit port
			-- and an address latch, so all memory accesses except for internal
			-- palette RAM should take 2 Cycles, which is implemented by this process
									
			PPU_ReadWrite_delay <= PPU_ReadWrite;
			CHR_Address <= (others => '0');
			
			if PPU_Address(13 downto 8) = X"3F" then
				-- Palette RAM Access takes just a single cycle
				if PPU_ReadWrite = '1' then
					PPU_Data_r <= PaletteRAM(to_integer(PPU_Address(4 downto 0)));
				else
					PaletteRAM(to_integer(PPU_Address(4 downto 0))) <= PPU_Data_w;
				end if;
			else 
				CHR_Address <= PPU_Address; -- Address only shows up externally for non-Palette RAM
				if PPU_Address(13) = '0' then -- Cartridge CHR-RAM/ROM
					-- CHR-RAM unimplemented for now
					PPU_Data_r <= CHR_Data;
				else -- SRAM
					-- The cartridge has tri-state access to the address lines A10/A11,
					-- so it can either provide additional 2k of SRAM, or tie them down
					-- to mirror the address range of the upper nametables to the lower ones
					
					-- Super Mario Brothers selects vertical mirroring (A11 tied down),
					-- so thats what we are doing here for now
					
					if PPU_ReadWrite_delay = '1' then
						PPU_Data_r <= VRAMData(to_integer(CHR_Address(10 downto 0)));
					else
						VRAMData(to_integer(CHR_Address(10 downto 0))) <= PPU_Data_w;
					end if;
				end if;
			end if;
		end if;
	end process;

end arch;

