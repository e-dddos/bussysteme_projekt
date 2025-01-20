
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;

entity seven_segment_display is
	generic(NUM_SENSORS : integer := 4);
    Port ( clk,
        tempval_ready, 
        sresetn : in std_logic;
        sensor_address: in std_logic_vector(1 downto 0); --id of the sensor which sends new data
        sensor_select: in std_logic_vector(1 downto 0); --id of sensor data to be displayed
        tempval_in : in std_logic_vector(11 downto 0); --temperature input
        seven_segments_out : out  std_logic_vector(6 downto 0); --7-segments for display, 0=on, 1=off
        decimal_point_out : out std_logic; --decimal point for display, 0=on, 1=off
        digit_enable_out: out  std_logic_vector(3 downto 0)); --anodes for activating each digit. 0=on, 1=off
end seven_segment_display;

architecture behavioural of seven_segment_display is
type DIGITS_ARRAY is array(9 downto 0) of std_logic_vector(6 downto 0);
type TEMPVAL_ARRAY is array(NUM_SENSORS-1 downto 0) of std_logic_vector(11 downto 0);
type INTEGER_ARRAY is array (0 to NUM_SENSORS-1) of integer;
type STATES is (D0, D1, D2, D3, RESET);

constant TURN_OFF_DELAY_SEC : integer := 5; -- period in seconds after which the display section for a sensor is turned off if no data is received
constant DIGIT_PERIOD: integer := 1000; -- 1 ms

signal tempval_reg, tempval_reg_next: TEMPVAL_ARRAY := (others => ("100000000000")); -- -128 means no data available
signal whole_part, whole_part_next: INTEGER_ARRAY := (others => 0);
signal fractional_part, fractional_part_next: INTEGER_ARRAY := (others => 0);
signal timeout_cnt, timeout_cnt_next: INTEGER_ARRAY := (others => 0);

signal state, state_next: STATES := RESET;
signal Q, Q_next: integer range 0 to DIGIT_PERIOD := 0;

signal digit_en, digit_en_next: std_logic_vector(3 downto 0) := (others => '1'); 
signal digits_out, digits_out_next: std_logic_vector(6 downto 0) := (others => '1'); 
signal dec_point_reg, dec_point_reg_next: std_logic := '1';

constant digits: DIGITS_ARRAY := (0 => "1000000", 
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

--state register
STATE_REG : process(clk, sresetn)
begin
    if rising_edge(clk) then
        if sresetn='1' then
            state <= RESET;
        else
            state <= state_next;
        end if;
    end if;
end process;

--data register
DATA_REG : process(clk, sresetn)
begin
    if (clk'event and clk = '1') then
        if sresetn='1' then -- define reset state
            Q <= 0;
            digit_en <= (others => '1'); -- all digits off
            digits_out <= (others => '1'); -- all segments off
            dec_point_reg <= '1';
            tempval_reg <= (others => ("100000000000"));
            timeout_cnt <= (others => 0);
            whole_part <= (others => 0);
            fractional_part <= (others => 0);
        else
            Q <= Q_next;
            digit_en <= digit_en_next;
            digits_out <= digits_out_next;
            dec_point_reg <= dec_point_reg_next;
            tempval_reg <= tempval_reg_next;
            timeout_cnt <= timeout_cnt_next;
            whole_part <= whole_part_next;
            fractional_part <= fractional_part_next;
        end if;
    end if;
end process;

--control path
CONTROL_PATH : process(state, Q, whole_part, fractional_part, digits_out, tempval_reg, sensor_select, tempval_ready)
begin
    --default values
    state_next <= state;
    case state is
        when RESET =>
            if Q = DIGIT_PERIOD then
                state_next <= D0;
            end if;
        when D0 =>
            if Q = DIGIT_PERIOD then
                state_next <= D1;
            end if;
        when D1 =>
            if Q = DIGIT_PERIOD then
                state_next <= D2;
            end if;
        when D2 =>
            if Q = DIGIT_PERIOD then
                state_next <= D3;
            end if;            
        when D3 =>
            if Q = DIGIT_PERIOD then
                state_next <= D0;
            end if;
    end case;
end process;

DATA_PATH : process(state, Q, whole_part, fractional_part, digits_out, tempval_reg, sensor_select, tempval_ready, timeout_cnt, tempval_in, sensor_address)
begin
    ----------default values-----------
    Q_next <= Q + 1;
    digits_out_next <= digits_out;
    digit_en_next <= digit_en;
    dec_point_reg_next <= dec_point_reg;
    tempval_reg_next <= tempval_reg;
    whole_part_next <= whole_part;
    fractional_part_next <= fractional_part;
    for i in 0 to NUM_SENSORS-1 loop
        timeout_cnt_next(i) <= timeout_cnt(i) + 1; -- increment timeout counter
    end loop;
    --state-independent data operations:---------
    for i in 0 to NUM_SENSORS-1 loop
        if timeout_cnt(i) = TURN_OFF_DELAY_SEC * 1000000 then -- if no data is received for TURN_OFF_DELAY_SEC
            tempval_reg_next(i) <= "100000000000"; -- set the whole part to -128 to represent invalid data
        end if;
    end loop;
    --if the temperature value is ready, store it in the corresponding register
    if tempval_ready='1' then 
        timeout_cnt_next(to_integer(unsigned(sensor_address))) <= 0; -- reset no value timeout counter
        tempval_reg_next(to_integer(unsigned(sensor_address))) <= tempval_in; -- save the temperature value
    end if;

    for i in 0 to NUM_SENSORS-1 loop
        whole_part_next(i) <= to_integer(signed(tempval_reg(i)(11 downto 4)));
        fractional_part_next(i) <= to_integer(unsigned(tempval_reg(i)(3 downto 0))) * 6;
    end loop;
     --resolution of ~0.0625 °C
    --for negative numbers, the fractional part is still positive, so it is added to the whole part
    --that means, if the fractional part is greater than zero, the whole part has to be incremented by one and the fractional part is inverted (100 - fractional part)
    --for example: 1111 1111 0101 1110 has -11 as whole part and 14*6 = 84 (0,84) as fractional part:
    ---11 + 0,84 = -10,16 <=>
    --whole part: -11 + 1 = -10 
    --fractional part:  (1 - 0,84) = 0,16
    --output : -10,16
    for i in 0 to NUM_SENSORS-1 loop
        if tempval_reg(i)(11) ='1' then -- negative flag
            if unsigned(tempval_reg(i)(3 downto 0)) > 0 then --fractional part is greater than zero
                whole_part_next(i) <= to_integer(signed(tempval_reg(i)(11 downto 4))) + 1;
                fractional_part_next(i) <= 100 - to_integer(unsigned(tempval_reg(i)(3 downto 0))) * 6; 
            end if;
        end if;
    end loop;
    --state-dependent data operations:------------
    case state is
        when RESET => -- all digits off
            digit_en_next <= "1111"; -- all digits off
            if Q = DIGIT_PERIOD then
                Q_next <= 0;
            end if;
        when D0 => -- digit 0 (rightmost digit)
            digit_en_next <= "1110";
            digits_out_next <= digits(abs(fractional_part(to_integer(unsigned(sensor_select)))) / 10 mod 10);
            --rounding:
            if (fractional_part(to_integer(unsigned(sensor_select))) mod 10) > 5 then
                digits_out_next <= digits((abs(fractional_part(to_integer(unsigned(sensor_select)))) / 10 mod 10) + 1);
            end if;
            -- if no data available, we show 4 minus signs
            if whole_part(to_integer(unsigned(sensor_select))) = -128 then
                digits_out_next <= minus;
            end if;
            --go to next digit:
            if Q = DIGIT_PERIOD then
                Q_next <= 0;
            end if;
        when D1 => -- digit 1
            digit_en_next <= "1101";
            digits_out_next <= digits(abs(whole_part(to_integer(unsigned(sensor_select)))) mod 10);
            dec_point_reg_next <= '0';
            -- if no data available, we show 4 minus signs
            if whole_part(to_integer(unsigned(sensor_select))) = -128 then
                digits_out_next <= minus;
                dec_point_reg_next <= '1';
            end if;
            if Q = DIGIT_PERIOD then
                Q_next <= 0;
                dec_point_reg_next <= '1';
            end if;
        when D2 => -- digit 2
            digit_en_next <= "1011";
            digits_out_next <= digits(abs(whole_part(to_integer(unsigned(sensor_select)))) / 10 mod 10);
            -- if no data available, we show 4 minus signs
            if whole_part(to_integer(unsigned(sensor_select))) = -128 then
                digits_out_next <= minus;
            end if;
            if Q = DIGIT_PERIOD then
                Q_next <= 0;
            end if;            
        when D3 => -- digit 3 (leftmost digit)
            digit_en_next <= "0111";
            if tempval_reg(to_integer(unsigned(sensor_select)))(11) ='1' then -- negative flag
                digits_out_next <= minus;
            else
                digits_out_next <= digits(abs(whole_part(to_integer(unsigned(sensor_select)))) / 100 mod 10);
            end if;
            -- if no data available, we show 4 minus signs
            if whole_part(to_integer(unsigned(sensor_select))) = -128 then
                digits_out_next <= minus;
            end if;
            if Q = DIGIT_PERIOD then
                Q_next <= 0;
            end if;
    end case;
end process;

-- forward registers to the outputs
digit_enable_out <= digit_en;
seven_segments_out <= digits_out;
decimal_point_out <= dec_point_reg;

end behavioural;