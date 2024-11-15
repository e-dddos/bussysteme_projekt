
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;

entity Lab1 is
    Port ( clk, sresetn : in std_logic;
           seg : out  std_logic_vector(6 downto 0);
           an: out  std_logic_vector(3 downto 0));
end Lab1;

architecture AND_4 of Lab1 is
type STD_LOGIC_ARRAY is array(9 downto 0) of std_logic_vector(6 downto 0);
type STATES is (D0, D1, D2, D3, RESET);
signal clk_en : std_logic := '0'; --clock enable signal
--signal led: std_logic := '0';
signal counter : integer := 0;
constant divisor: integer := 50000000; -- for clock 10 Hz: 100 MHZ/Divisor
--constant divisor: std_logic_vector(27 downto 0) := x"0000002"; -- for simulation
signal digit, digit_next: integer := 0;

signal state, state_next: STATES := RESET;
 
constant all_on: std_logic_vector(3 downto 0) := "0000";

constant digits: STD_LOGIC_ARRAY := (0 => "1000000", 
                          1 => "1111001",
                          2 => "0100100",
                          3 => "0110000",
                          4 => "0011001",
                          5 => "0010010",
                          6 => "0000010",
                          7 => "1111000",
                          8 => "0000000",
                          9 => "0010000"
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

DISPLAY_REG : process(clk, clk_en, digit_next)
begin
  if (clk'event and clk = '1') then
        if(clk_en = '1') then
            if sresetn='1' then -- define reset state
                digit <= 0;
            else
                digit <= digit_next;
            end if;
        end if;
    end if;
end process;

DISPLAY_COMB : process(digit)
begin
        if(digit = 9) then
            digit_next <= 0;
        else   
            digit_next <= digit + 1;        
            end if;
end process;

an <= all_on;
seg <= digits(digit);

end AND_4;



             