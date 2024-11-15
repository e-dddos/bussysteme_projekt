
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;

entity Lab1 is
    Port ( clk, sresetn : in std_logic;
            sw : in std_logic_vector(12 downto 0);
           seg : out  std_logic_vector(6 downto 0);
           an: out  std_logic_vector(3 downto 0));
end Lab1;

architecture AND_4 of Lab1 is
type STD_LOGIC_ARRAY is array(9 downto 0) of std_logic_vector(6 downto 0);
type STATES is (D0, D1, D2, D3, RESET);
signal clk_en : std_logic := '0'; --clock enable signal
--signal led: std_logic := '0';
signal counter : integer := 0;
constant divisor: integer := 100; -- for clock 1 MHz: 100 MHZ/Divisor
--constant divisor: std_logic_vector(27 downto 0) := x"0000002"; -- for simulation
signal digit, digit_next: integer := 0;
signal number: integer := 0;
signal state, state_next: STATES := RESET;
signal Q, Q_next: integer := 0;
signal digit_en, digit_en_next: std_logic_vector(3 downto 0) := "0000"; 
signal digits_out, digits_out_next: std_logic_vector(6 downto 0) := "0000000"; 

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

constant digit_period: integer := 4000; -- 1 ms
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

INPUT_NUMBER : process(sw)
begin
    number <= to_integer(unsigned(sw(12 downto 0)));
end process;


DISPLAY_REG : process(clk, clk_en, digit_next)
begin
  if (clk'event and clk = '1') then
        if(clk_en = '1') then
            if sresetn='1' then -- define reset state
                state <= RESET;
                Q <= 0;
                digit_en <= "1111";
                digit <= 0;
                digits_out <= "1111111";
            else
                state <= state_next;
                Q <= Q_next;
                digit_en <= digit_en_next;
                digit <= digit_next;
                digits_out <= digits_out_next;
            end if;
        end if;
    end if;
end process;

DISPLAY_COMB : process(state, Q, number)
begin
        --default values
        state_next <= state;
        Q_next <= Q + 1;
        digits_out_next <= digits_out;
        digit_en_next <= digit_en;
        case state is
            when RESET =>
                digit_en_next <= "1111"; -- all digits off
                if Q = digit_period then
                    state_next <= D0;
                    Q_next <= 0;
                end if;
            when D0 =>
                digit_next <= number mod 10;
                digits_out_next <= digits(number mod 10);
                digit_en_next <= "1110";
                if Q = digit_period then
                    state_next <= D1;
                    Q_next <= 0;
                end if;
            when D1 =>
                digit_next <= number / 10 mod 10;
                digits_out_next <= digits(number / 10 mod 10);
                digit_en_next <= "1101";
                if Q = digit_period then
                    state_next <= D2;
                    Q_next <= 0;
                end if;
            when D2 =>
                digit_next <= number / 100 mod 10;
                digits_out_next <= digits(number / 100 mod 10);
                digit_en_next <= "1011";
                if Q = digit_period then
                    state_next <= D3;
                    Q_next <= 0;
                end if;            
            when D3 =>
                digit_next <= number / 1000 mod 10;
                digits_out_next <= digits(number / 1000 mod 10);
                digit_en_next <= "0111";
                if Q = digit_period then
                    state_next <= RESET;
                    Q_next <= 0;
                end if;
        end case;
end process;
-- forward outputs out
an <= digit_en;
seg <= digits_out;

end AND_4;



             