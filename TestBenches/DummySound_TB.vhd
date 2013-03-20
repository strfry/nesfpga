LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

use STD.textio.ALL;

ENTITY DummySound_TB IS
END DummySound_TB;
 
ARCHITECTURE behavior OF DummySound_TB IS 
 
   COMPONENT DummySound
   PORT(
     CLK : IN  std_logic;
     CE : IN  std_logic;
     RSTN : IN  std_logic;

     PCM_4BIT_OUT : out signed(3 downto 0)


--     VRAM_Address : OUT  unsigned(13 downto 0);
--     VRAM_Data : IN  std_logic_vector(7 downto 0);
     );
   END COMPONENT;
      

   --Outputs
  signal DUMMY_PCM : unsigned(3 downto 0) := X"0";

  -- Clock period definitions
  constant AC97_CLK_period : time := 20.833333333333332 us; -- 48 kHz
  constant CLK_period : time := 46.560848137510206 ns; -- 21.477272 MhZ
  
  constant APU_clkdiv : integer := 2 * 12; -- Half CPU Clock

  signal AC97_CLK : std_logic := '0';
  
  signal CLK : std_logic := '0';
  signal APU_CE : std_logic := '0';
  signal RSTN : std_logic := '0';
  
  signal APU_CE_cnt : integer := 0;
 
BEGIN


  APU_CE <= '1' when APU_CE_cnt = 0 else '0';
  
  CLK <= not CLK after CLK_period;
  AC97_CLK <= not AC97_CLK after AC97_CLK_period;
  RSTN <= '1' after 100 ns;
  
  process (clk)
  begin
    if rising_edge(clk) then
      if APU_CE_cnt = APU_clkdiv - 1 then
        APU_CE_cnt <= 0;
      else
        APU_CE_cnt <= APU_CE_cnt + 1;
      end if;
    end if;
  end process;
 
--  uut: APU_Pulse PORT MAP (
--    CLK => CLK,
--    CE => CE,
--    RSTN => RSTN
--  );
--    

  APU_PULSE : process(CLK)
    variable note : unsigned(11 downto 0) := X"0FD";
    variable sequencer : std_logic_vector(7 downto 0) := "11110000";
    variable timer : integer := 0;
  begin
    if rising_edge(CLK) and APU_CE = '1' then
      if timer = 0 then
        timer := to_integer(note);
	sequencer := sequencer(6 downto 0) & sequencer(7);
        DUMMY_PCM <= X"0";
	if sequencer(0) = '1' then DUMMY_PCM <= X"F"; end if;
      else
        timer := timer - 1;
      end if;
    end if;
  end process;
  
  
  WRITE_OUTPUT_proc : process(AC97_CLK)
    type AudioFileType is file of character;
    file outfile : AudioFileType open WRITE_MODE is "audio.dump";
    variable num_samples : integer := 0;
  begin
    if rising_edge(AC97_CLK)  then
      write(outfile, character'val(to_integer(DUMMY_PCM & "0000")));
--        write(outfile, character'val(num_samples));
      
      num_samples := num_samples + 1;

      assert num_samples mod 48000 /= 0 report "Wrote 1000 ms" severity note;
	

    end if;
  end process;

END;
