library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.T65_Pack.all;

package Pack_2A03 is
	component T65
	port(
		Mode    : in  std_logic_vector(1 downto 0);      -- "00" => 6502, "01" => 65C02, "10" => 65C816
		Res_n   : in  std_logic;
		Enable  : in  std_logic;
		Clk     : in  std_logic;
		Clk_Phi2: in  std_logic;
		Clk_AddOK : in std_logic;
		Clk_ReadOK : in std_logic;
		Rdy     : in  std_logic;
		--Abort_n : in  std_logic;
		IRQ_n   : in  std_logic;
		NMI_n   : in  std_logic;
		SO_n    : in  std_logic;
		R_W_n   : out std_logic;
		Sync    : out std_logic;
		ML_n    : out std_logic;
		VP_n    : out std_logic;
		VDA     : out std_logic;
		VPA     : out std_logic;
		T65Address       : out std_logic_vector(15 downto 0);
		T65DataIn      : in  std_logic_vector(7 downto 0);
		T65DataOut      : out std_logic_vector(7 downto 0)
		--Added for debugging
		--T65_LCycle : out std_logic_vector(2 downto 0);
		--T65_MCycle : out std_logic_vector(2 downto 0);
		--T65_InitialReset : out std_logic
	);
	end component;
	
	component Clock_Divider
	port(
		Clk_In, Reset_N, Enable: in std_logic;
		Clk_Out : out std_logic;
		Clk_Out_Phi2 : out std_logic;
		Clk_Out_AddOK : out std_logic;
		Clk_Out_WriteOK : out std_logic;
		Clk_Out_ReadOK : out std_logic;
		In_Out : buffer std_logic
		);
	end component;
	
	component SRAM
	port(
		Clock				: in std_logic;
		ChipSelect_N	: in std_logic;
		WriteEnable_N	: in std_logic;
		OutputEnable_N : in std_logic;
		Address			: in std_logic_vector (10 downto 0);
		Data				: inout std_logic_vector (7 downto 0)
		);
	end component;
end Pack_2A03;
