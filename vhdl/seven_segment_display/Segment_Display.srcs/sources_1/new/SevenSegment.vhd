
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;

entity seven_segment_display is
    Port ( clk,
        tempval_ready, 
        sresetn : in std_logic;
        tempval_in : in std_logic_vector(15 downto 0); --temperature input
        seven_segments_out : out  std_logic_vector(6 downto 0); --7-segments for display, 0=on, 1=off
        decimal_point_out : out std_logic; --decimal point for display, 0=on, 1=off
        digit_enable_out: out  std_logic_vector(3 downto 0)); --anodes for activating each digit. 0=on, 1=off
end seven_segment_display;

architecture behavioural of seven_segment_display is
type STD_LOGIC_VECTOR_ARRAY is array(9 downto 0) of std_logic_vector(6 downto 0);
type STATES is (D0, D1, D2, D3, RESET);

--clock stuff:
signal clk_en : std_logic := '0'; --clock enable signal
--signal led: std_logic := '0';
constant divisor: integer := 100; -- for clock 1 MHz: 100 MHZ/Divisor
signal counter : integer range 0 to divisor := 0;
--constant divisor: std_logic_vector(27 downto 0) := x"0000002"; -- for simulation


signal tempval_reg, tempval_reg_next: std_logic_vector(15 downto 0) := (others => '0');
signal whole_part: integer range -128 to 127 := 0;
signal fractional_part: integer range 0 to 99 := 0;


signal state, state_next: STATES := RESET;
constant digit_period: integer := 1000; -- 1 ms
signal Q, Q_next: integer range 0 to digit_period := 0;

signal digit_en, digit_en_next: std_logic_vector(3 downto 0) := (others => '1'); 
signal digits_out, digits_out_next: std_logic_vector(6 downto 0) := (others => '1'); 
signal dec_point_reg, dec_point_reg_next: std_logic := '1';

constant digits: STD_LOGIC_VECTOR_ARRAY := (0 => "1000000", 
                                            1 => "1111001",
                                            2 => "0100100",
                                            3 => "0110000",
                                            4 => "0011001",
                                            5 => "0010010",
                                            6 => "0000010",
                                            7 => "1111000",
                                            8 => "0000000",
                                            9 => "0010000");
constant minus: std_logic_vector(6 downto 0)  := "0111111";

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

INPUT_NUMBER : process(tempval_in, tempval_ready)
begin
    if tempval_ready='1' then 
        tempval_reg_next <= tempval_in;
    else
        tempval_reg_next <= tempval_reg;
    end if; 
end process;

CALC_WHOLE_FRACTIONAL : process(tempval_reg)
begin
-- bit 11 contains the sign, so the bits 11 to 4 can be interpreted as a signed integer
-- the bits 3 to 0 contain the fractional part
--default:
    whole_part <= to_integer(signed(tempval_reg(11 downto 4)));
    fractional_part <= to_integer(unsigned(tempval_reg(3 downto 0))) * 6; --resolution of ~0.0625 °C
    --for negative numbers, the fractional part is still positive, so it is added to the whole part
    --that means, if the fractional part is greater than zero, the whole part has to be incremented by one and the fractional part is inverted (100 - fractional part)
    --for example: 1111 1111 0101 1110 has -11 as whole part and 14*6 = 84 (0,84) as fractional part:
    ---11 + 0,84 = -10,16 <=>
    --whole part: -11 + 1 = -10 
    --fractional part:  (1 - 0,84) = 0,16
    --output : -10,16
    
    if tempval_reg(11) ='1' then -- negative flag
        if unsigned(tempval_reg(3 downto 0)) > 0 then --fractional part is greater than zero
            whole_part <= to_integer(signed(tempval_reg(11 downto 4))) + 1;
            fractional_part <= 100 - to_integer(unsigned(tempval_reg(3 downto 0))) * 6; 
        end if;
    end if;

end process;


DISPLAY_REG : process(clk, clk_en, sresetn)
begin
  if (clk'event and clk = '1') then
        if(clk_en = '1') then
            if sresetn='1' then -- define reset state
                state <= RESET;
                Q <= 0;
                digit_en <= (others => '1'); -- all digits off
                digits_out <= (others => '1'); -- all segments off
                dec_point_reg <= '1';
                tempval_reg <= (others => '0');
            else
                state <= state_next;
                Q <= Q_next;
                digit_en <= digit_en_next;
                digits_out <= digits_out_next;
                dec_point_reg <= dec_point_reg_next;
                tempval_reg <= tempval_reg_next;
            end if;
        end if;
    end if;
end process;

DISPLAY_COMB : process(state, Q, whole_part, fractional_part, digits_out, tempval_reg)
begin
        --default values
        state_next <= state;
        Q_next <= Q + 1;
        digits_out_next <= digits_out;
        digit_en_next <= digit_en;
        dec_point_reg_next <= dec_point_reg;
        case state is
            when RESET =>
                digit_en_next <= "1111"; -- all digits off
                if Q = digit_period then
                    state_next <= D0;
                    Q_next <= 0;
                end if;
            when D0 =>
                digit_en_next <= "1110";
                digits_out_next <= digits(abs(fractional_part) / 10 mod 10);
                --rounding:
                if (fractional_part mod 10) > 5 then
                    digits_out_next <= digits((abs(fractional_part) / 10 mod 10) + 1);
                end if;
                if Q = digit_period then
                    state_next <= D1;
                    Q_next <= 0;
                end if;
            when D1 =>
                digit_en_next <= "1101";
                digits_out_next <= digits(abs(whole_part) mod 10);
                dec_point_reg_next <= '0';
                if Q = digit_period then
                    state_next <= D2;
                    Q_next <= 0;
                    dec_point_reg_next <= '1';
                end if;
            when D2 =>
                digit_en_next <= "1011";
                digits_out_next <= digits(abs(whole_part) / 10 mod 10);
                if Q = digit_period then
                    state_next <= D3;
                    Q_next <= 0;
                end if;            
            when D3 =>
                digit_en_next <= "0111";
                if tempval_reg(11) ='1' then -- negative flag
                    digits_out_next <= minus;
                else
                    digits_out_next <= digits(abs(whole_part) / 100 mod 10);
                end if;
                if Q = digit_period then
                    state_next <= RESET;
                    Q_next <= 0;
                end if;
        end case;
end process;
-- forward outputs out
digit_enable_out <= digit_en;
seven_segments_out <= digits_out;
decimal_point_out <= dec_point_reg;

end behavioural;