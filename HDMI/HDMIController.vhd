library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity HDMIController is
	port (
		CLK : in std_logic;
		RSTN : in std_logic;
		
		CLK_50 : in std_logic;

		HDMIHSync : OUT  std_logic;
		HDMIVSync : OUT  std_logic;
		HDMIDE : OUT  std_logic;
		HDMICLKP : OUT  std_logic;
		HDMICLKN : OUT  std_logic;
		HDMID : OUT  std_logic_vector(11 downto 0);
		HDMISCL : INOUT  std_logic;
		HDMISDA : INOUT  std_logic;
		HDMIRSTN : OUT  std_logic
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
		TFT_VGA_R : out std_logic;
		TFT_VGA_G : out std_logic;
		TFT_VGA_B : out std_logic;
		
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
	
	signal HSYNC : std_logic;
	signal VSYNC : std_logic;
	signal DE : std_logic;
	signal RED : std_logic_vector(5 downto 0);
	signal GREEN : std_logic_vector(5 downto 0);
	signal BLUE : std_logic_vector(5 downto 0);

begin


	interface : tft_interface
	port map (
		TFT_Clk => CLK_50,
		TFT_Rst => RSTN,          
		Bus2IP_Clk => CLK,        
		Bus2IP_Rst => RSTN,       
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
		TFT_IIC_SCL_I => '0',   
		TFT_IIC_SCL_O => HDMISCL,   
		TFT_IIC_SCL_T => open,   
		TFT_IIC_SDA_I => '0',   
		TFT_IIC_SDA_O => HDMISDA,   
		TFT_IIC_SDA_T => open,   
		IIC_xfer_done => open,   
		TFT_iic_xfer => '0',    
		TFT_iic_reg_addr => (others => '-'),
		TFT_iic_reg_data => (others => '-')
);


end Behavioral;



