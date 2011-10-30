library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

entity HDMIController is
	port (
		CLK : in std_logic;
		RSTN : in std_logic;
		
		CLK_25 : in std_logic;

		HDMIHSync : OUT  std_logic;
		HDMIVSync : OUT  std_logic;
		HDMIDE : OUT  std_logic;
		HDMICLKP : OUT  std_logic;
		HDMICLKN : OUT  std_logic;
		HDMID : OUT  std_logic_vector(11 downto 0);
		HDMISCL : INOUT  std_logic;
		HDMISDA : INOUT  std_logic;
		HDMIRSTN : OUT  std_logic;
		
		FB_Address : out std_logic_vector(15 downto 0);
		FB_Data : in std_logic_vector(5 downto 0)
	 
	);
end HDMIController;

architecture Behavioral of HDMIController is

	component tft_interface
	port (
		TFT_Clk : in std_logic;
		TFT_Rst : in std_logic;
		Bus2IP_Clk : in std_logic;
		Bus2IP_Rst : in std_logic;
		
		HSYNC : in std_logic;
		VSYNC : in std_logic;
		DE : in std_logic;
		RED : in std_logic_vector(5 downto 0);
		GREEN : in std_logic_vector(5 downto 0);
		BLUE : in std_logic_vector(5 downto 0);
		
		TFT_HSYNC : out std_logic;
		TFT_VSYNC : out std_logic;
		TFT_DE : out std_logic;
		TFT_VGA_CLK : out std_logic;
		TFT_VGA_R : out std_logic_vector(5 downto 0);
		TFT_VGA_G : out std_logic_vector(5 downto 0);
		TFT_VGA_B : out std_logic_vector(5 downto 0);
		
		TFT_DVI_CLK_P : out std_logic;
		TFT_DVI_CLK_N : out std_logic;
		TFT_DVI_DATA : out std_logic_vector(11 downto 0);
		
		I2C_done : out std_logic;
		TFT_IIC_SCL_I : in std_logic;
		TFT_IIC_SCL_O : out std_logic;
		TFT_IIC_SCL_T : out std_logic;
		TFT_IIC_SDA_I : in std_logic;
		TFT_IIC_SDA_O : out std_logic;
		TFT_IIC_SDA_T : out std_logic;
		
		IIC_xfer_done : out std_logic;
		TFT_iic_xfer : in std_logic;
		TFT_iic_reg_addr : in std_logic_vector(0 to 7);
		TFT_iic_reg_data : in std_logic_vector(0 to 7)
	);
	end component;
	
	component ColorPalette is
	port (
		ColorIndex : in  unsigned (5 downto 0);
      Red : out  STD_LOGIC_VECTOR (5 downto 0);
      Green : out  STD_LOGIC_VECTOR (5 downto 0);
      Blue : out  STD_LOGIC_VECTOR (5 downto 0)
	);
	end component;
	
	signal HSYNC : std_logic;
	signal VSYNC : std_logic;
	signal DE : std_logic;
	signal RED : std_logic_vector(5 downto 0);
	signal GREEN : std_logic_vector(5 downto 0);
	signal BLUE : std_logic_vector(5 downto 0);
	
	signal TFT_IIC_SCL_I : std_logic;
	signal TFT_IIC_SCL_O : std_logic;
	signal TFT_IIC_SCL_T : std_logic;
	signal TFT_IIC_SDA_I : std_logic;
	signal TFT_IIC_SDA_O : std_logic;
	signal TFT_IIC_SDA_T : std_logic;
	
	signal HSYNC_cnt : integer := 0;
	signal VSYNC_cnt : integer := 0;
	
	signal FB_Address_int : integer;
	
	signal VSYNC_delay : std_logic_vector(0 to 3);
	signal RST : std_logic;

begin
	
	HDMIRSTN <= RSTN;
	RST <= not RSTN;



	VSYNC_delay(2) <= '0' when VSYNC_cnt < 2 else '1';
	VSYNC <= VSYNC_delay(0);

	HSYNC <= '0' when HSYNC_cnt < 96 else '1';
	
	DE <= '1' when HSYNC_cnt >= 144 and HSYNC_cnt < 784 and VSYNC_cnt >= 33 and VSYNC_cnt < 513 else '0';
	
	process (VSYNC_cnt, HSYNC_cnt)
	variable addr_int : integer;
	begin
		addr_int := (VSYNC_cnt - 33) / 2 * 256 + (HSYNC_cnt - 144) / 2;
		if addr_int >= 57344 then
			addr_int := 0;
		end if;
		FB_Address <= std_logic_vector(to_unsigned(addr_int, FB_Address'length));
	end process;
	
	process (CLK_25)
	begin
		if rising_edge(CLK_25) then
			VSYNC_delay(0 to 1) <= VSYNC_delay(1 to 2);
		end if;
	end process;

	process (CLK_25)
	begin
		if rising_edge(CLK_25) then
			if RSTN = '0' then
				HSYNC_cnt <= 0;
				VSYNC_cnt <= 0;
			else
				if HSYNC_cnt < 800 - 1 then
					HSYNC_cnt <= HSYNC_cnt + 1;
				else
					HSYNC_cnt <= 0;
					if VSYNC_cnt < 525 - 1 then
						VSYNC_cnt <= VSYNC_cnt + 1;
					else
						VSYNC_cnt <= 0;
					end if;
				end if;				
			end if;
		end if;
	end process;
	
	
	IISC_SCL_BUF: IOBUF
	port map (
		I => TFT_IIC_SCL_O,
		O => TFT_IIC_SCL_I,
		T => TFT_IIC_SCL_T,
		IO => HDMISCL
	);
	
	IISC_SDA_BUF: IOBUF
	port map (
		I => TFT_IIC_SDA_O,
		O => TFT_IIC_SDA_I,
		T => TFT_IIC_SDA_T,
		IO => HDMISDA
	);


	interface : tft_interface
	port map (
		TFT_Clk => CLK_25,
		TFT_Rst => RST, 
		Bus2IP_Clk => CLK,        
		Bus2IP_Rst => RST,       
		HSYNC => HSYNC,           
		VSYNC => VSYNC,           
		DE => DE,                 
		RED => RED,               
		GREEN => GREEN,           
		BLUE => BLUE,             


		TFT_HSYNC => HDMIHSync,   
		TFT_VSYNC => HDMIVSync,
		TFT_DE => HDMIDE,

		TFT_VGA_CLK => open,     
		TFT_VGA_R => open,
		TFT_VGA_G => open,
		TFT_VGA_B => open,

		TFT_DVI_CLK_P => HDMICLKP,
		TFT_DVI_CLK_N => HDMICLKN,
		TFT_DVI_DATA => HDMID,

		I2C_done => open,
		TFT_IIC_SCL_I => TFT_IIC_SCL_I,   
		TFT_IIC_SCL_O => TFT_IIC_SCL_O,   
		TFT_IIC_SCL_T => TFT_IIC_SCL_T,   
		TFT_IIC_SDA_I => TFT_IIC_SDA_I,   
		TFT_IIC_SDA_O => TFT_IIC_SDA_O,   
		TFT_IIC_SDA_T => TFT_IIC_SDA_T,   
		IIC_xfer_done => open,   
		TFT_iic_xfer => '0',    
		TFT_iic_reg_addr => "--------",
		TFT_iic_reg_data => "--------"
);

	PALETTE : ColorPalette
	port map (
		ColorIndex => unsigned(FB_Data),
		Red => RED,
		Green => GREEN,
		Blue => BLUE
	);


end Behavioral;



