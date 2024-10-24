
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;

entity Lab1 is
    Port ( clk : in std_logic;
           led : out  std_logic_vector(15 downto 0));
end Lab1;

architecture AND_4 of Lab1 is
signal clk_en : std_logic := '0'; --clock enable signal
--signal led: std_logic := '0';
signal slow_counter: std_logic_vector(15 downto 0) := (others => '0');
signal counter : integer := 0;
constant divisor: integer := 10000000; -- for clock 10 Hz: 100 MHZ/Divisor
--constant divisor: integer := 2; -- for simulation

begin

CLK_DIV : process(clk)
begin
  if (clk'event and clk = '1') then
    if(counter = divisor) then
      counter <= 0;
      clk_en <= '1';
    else
      clk_en <= '0';
      counter <= counter + 1;
    end if;
  end if;
end process;

DISPLAY : process(clk)
begin
  if (clk'event and clk = '1') then
        if(clk_en = '1') then
            slow_counter <= slow_counter + 1;        
    end if;
  end if;
end process;
led <= slow_counter; -- assign output signal
end AND_4;
