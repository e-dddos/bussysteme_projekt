
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;

entity Lab1 is
    Port ( clk : in std_logic;
           seg : out  std_logic_vector(6 downto 0);
           an: out  std_logic_vector(3 downto 0));
end Lab1;

architecture AND_4 of Lab1 is
type STD_LOGIC_ARRAY is array(9 downto 0) of std_logic_vector(6 downto 0);

signal clk_en : std_logic := '0'; --clock enable signal
--signal led: std_logic := '0';
signal counter : integer := 0;
constant divisor: integer := 50000000; -- for clock 10 Hz: 100 MHZ/Divisor
--constant divisor: std_logic_vector(27 downto 0) := x"0000002"; -- for simulation

signal current_digit: integer := 0;
constant all_on: std_logic_vector(3 downto 0) := "0000";

constant digits: STD_LOGIC_ARRAY := (0 => "1111110", 
                          1 => "0110000",
                          2 => "1101101",
                          3 => "1111001",
                          4 => "0110011",
                          5 => "1011011",
                          6 => "1011111",
                          7 => "1110000",
                          8 => "1111111",
                          9 => "1111011"
                          );

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
            if(current_digit = 9) then
                current_digit <= 0;
                else   
                current_digit <= current_digit + 1;        
     end if;
    end if;
  end if;
end process;
an <= all_on;
seg <= digits(current_digit);

end AND_4;
