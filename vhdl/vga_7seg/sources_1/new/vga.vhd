 library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga is
    Port ( 
        vgaRed : out std_logic_vector(3 downto 0);
        vgaGreen : out std_logic_vector(3 downto 0);
        vgaBlue : out std_logic_vector(3 downto 0);
        Hsync : out std_logic;
        Vsync : out std_logic;
        
        clk : in std_logic;
        sresetn : in std_logic;
        
        tempval_ready: in std_logic;
        sensor_address: in std_logic_vector(1 downto 0);
        tempval_in : in std_logic_vector(11 downto 0) --temperature input
       -- clk_out : out std_logic;
       -- hcnt : out unsigned(10 downto 0);
       -- vcnt : out unsigned(10 downto 0)
    );
end vga;

architecture Behavioral of vga is
    --display resolution constants
    constant H_DISPLAY : integer := 640;
    constant H_FRONT_PORCH : integer := 16;
    constant H_SYNC_PULSE : integer := 96;
    constant H_BACK_PORCH : integer := 48;
    constant H_TOTAL : integer := H_DISPLAY + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH;

    constant V_DISPLAY : integer := 480;
    constant V_FRONT_PORCH : integer := 10;
    constant V_SYNC_PULSE : integer := 2;
    constant V_BACK_PORCH : integer := 33;
    constant V_TOTAL : integer := V_DISPLAY + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH;

    constant TURN_OFF_DELAY_SEC : integer := 5; -- period in seconds after which the display section for a sensor is turned off if no data is received

    signal pix_clock : std_logic := '0';
    signal clk_2 : std_logic := '0';
    signal cnt1, cnt1_next, cnt2, cnt2_next, cnt3, cnt3_next : unsigned(39 downto 0) := (others => '0');
    
    signal h_cnt : unsigned(9 downto 0) := (others => '0');
    signal v_cnt : unsigned(9 downto 0) := (others => '0');
    signal vgaRed_reg, vgaRed_reg_next: std_logic_vector(3 downto 0) := (others => '0');
    signal vgaGreen_reg, vgaGreen_reg_next: std_logic_vector(3 downto 0) := (others => '0');
    signal vgaBlue_reg, vgaBlue_reg_next: std_logic_vector(3 downto 0) := (others => '0');


    signal tempval1_reg, tempval1_reg_next: std_logic_vector(11 downto 0) := (others => '0');
    signal tempval2_reg, tempval2_reg_next: std_logic_vector(11 downto 0) := (others => '0');
    signal tempval3_reg, tempval3_reg_next: std_logic_vector(11 downto 0) := (others => '0');
    signal temperature_out, temp1, temp2, temp3: integer range -128 to 255 := -100;
    constant TEMP_OFFSET : integer := 96; -- for demo
begin

    --clk_out <= pix_clock;
    --hcnt <= h_cnt;
    --vcnt <= v_cnt;

    --Divide clock two times
    clk_div_2: process(clk, sresetn)
    begin
        if (sresetn = '1') then 
            clk_2 <= '0';
        elsif rising_edge(clk) then 
            clk_2 <= not clk_2;
        end if; 
    end process;

    pix_clk_gen: process(clk_2, sresetn)
    begin 
        if (sresetn = '1') then 
            pix_clock <= '0';
        elsif rising_edge(clk_2) then
            pix_clock <= not pix_clock;
        end if;
    end process;


    counter_reg: process(clk, sresetn)
    begin
        if rising_edge(clk) then
            if sresetn = '1' then
                cnt1 <= (others => '0');
                cnt2 <= (others => '0');
                cnt3 <= (others => '0');
            else
                cnt1 <= cnt1_next;
                cnt2 <= cnt2_next;
                cnt3 <= cnt3_next;
            end if;
        end if;
    end process;

    INPUT_NUMBER : process(tempval_in, tempval_ready, sensor_address, cnt1, cnt2, cnt3)
    begin
        --default values:
        tempval1_reg_next <= tempval1_reg;
        tempval2_reg_next <= tempval2_reg;
        tempval3_reg_next <= tempval3_reg;
        cnt1_next <= cnt1 + 1;
        cnt2_next <= cnt2 + 1;
        cnt3_next <= cnt3 + 1;
        --if the temperature value is ready, store it in the corresponding register
        if tempval_ready='1' then 
            case sensor_address is
                when "00" =>
                    cnt1_next <= (others => '0'); --reset counters
                    tempval1_reg_next <= tempval_in;
                when "01" =>
                    cnt2_next <= (others => '0');
                    tempval2_reg_next <= tempval_in;
                when "10" =>
                    cnt3_next <= (others => '0');
                    tempval3_reg_next <= tempval_in;
                when others =>
                    null;
            end case;
        end if;
    end process;

    convert_temp : process(tempval1_reg, tempval2_reg, tempval3_reg)
    begin
    -- bit 11 contains the sign, so the bits 11 to 4 can be interpreted as a signed integer
    -- for demo we'll take the 6 bits that represent the whole part of the temperature and 2 bits for the fractional part 
    -- and interpret them as a unsigned integer, so we can have more color change for lesser temperature changes
    -- in normal conditions we would take the bits 11 to 4, and the vga controller would be able to display meaningful colors
    -- in a range from -16 to 31 degrees. For demo we will have a range from 80 to 127, and so it makes sense we need to offset
    -- to not have to change the code after.  
    -- temp1 <= to_integer(unsigned(tempval1_reg(11 downto 4)));
    -- temp2 <= to_integer(unsigned(tempval2_reg(11 downto 4)));
    -- temp3 <= to_integer(unsigned(tempval3_reg(11 downto 4))); 
        temp1 <= to_integer(unsigned(tempval1_reg(9 downto 2))) - TEMP_OFFSET;
        temp2 <= to_integer(unsigned(tempval2_reg(9 downto 2))) - TEMP_OFFSET;
        temp3 <= to_integer(unsigned(tempval3_reg(9 downto 2))) - TEMP_OFFSET;
    end process;

    reg_process: process(pix_clock, sresetn) 
    begin
        if (sresetn = '1') then
            tempval1_reg <= (others => '0');
            tempval2_reg <= (others => '0');
            tempval3_reg <= (others => '0');
        elsif rising_edge(pix_clock) then
            tempval1_reg <= tempval1_reg_next;
            tempval2_reg <= tempval2_reg_next;
            tempval3_reg <= tempval3_reg_next;
            vgaRed_reg <= vgaRed_reg_next;
            vgaGreen_reg <= vgaGreen_reg_next;
            vgaBlue_reg <= vgaBlue_reg_next;
        end if;
        --if no value is received in TURN_OFF_DELAY_SEC seconds, turn off the corresponding display section
        if cnt1 = TURN_OFF_DELAY_SEC * 100000000 then
            tempval1_reg <= std_logic_vector(to_unsigned(0, 12));
        end if;
        if cnt2 = TURN_OFF_DELAY_SEC * 100000000 then
            tempval2_reg <= std_logic_vector(to_unsigned(0, 12));
        end if;
        if cnt3 = TURN_OFF_DELAY_SEC * 100000000 then
            tempval3_reg <= std_logic_vector(to_unsigned(0, 12));
        end if;
    end process;
    
    comb_process: process(h_cnt, v_cnt)
    begin
        if (h_cnt < H_DISPLAY and v_cnt < V_DISPLAY) then
                --lower than -16
                if (h_cnt < H_DISPLAY/3) then
                    temperature_out <= temp1;
                elsif (h_cnt < 2*H_DISPLAY/3) then
                    temperature_out <= temp2;
                else
                    temperature_out <= temp3;
                end if;
                if (temperature_out < -60) then --no valid temperature data
                    vgaRed_reg_next <= X"0";
                    vgaGreen_reg_next <= X"0";
                    vgaBlue_reg_next <= X"0";
                elsif (temperature_out < -16) then 
                    vgaRed_reg_next <= X"0";
                    vgaGreen_reg_next <= X"0";
                    vgaBlue_reg_next <= X"F";
                elsif (temperature_out >= 32) then --higher than 32 
                    vgaRed_reg_next <= X"F";
                    vgaGreen_reg_next <= X"0";
                    vgaBlue_reg_next <= X"0";
                elsif (temperature_out >= -16 and temperature_out <= -1) then -- [-16, -1]
                    vgaRed_reg_next <= X"0";
                    vgaGreen_reg_next <= std_logic_vector(to_unsigned(temperature_out + 16, 4));
                    vgaBlue_reg_next <= X"F";
                elsif (temperature_out >= 16 and temperature_out < 32) then -- [16, 31]
                    vgaRed_reg_next <= X"F";
                    vgaGreen_reg_next <= std_logic_vector(to_unsigned(15 - (temperature_out - 16), 4));
                    vgaBlue_reg_next <= X"0";
                else
                    vgaRed_reg_next <= std_logic_vector(to_unsigned(temperature_out, 4)); -- [0, 15]
                    vgaGreen_reg_next <= X"F";
                    vgaBlue_reg_next <= std_logic_vector(to_unsigned(15 - temperature_out, 4));
                end if;
            else -- blanking
                vgaRed_reg_next <= X"0";
                vgaGreen_reg_next <= X"0";
                vgaBlue_reg_next <= X"0";
            end if;
        -- I 
        if (h_cnt >= H_DISPLAY/3/2 and h_cnt < H_DISPLAY/3/2 + 3 and v_cnt >= 10 and v_cnt < 25) or
        -- II
        (h_cnt >= H_DISPLAY/2 - 4 and h_cnt < H_DISPLAY/2 - 1 and v_cnt >= 10 and v_cnt < 25) or
        (h_cnt >= H_DISPLAY/2 + 1 and h_cnt < H_DISPLAY/2 + 4 and v_cnt >= 10 and v_cnt < 25) or 
        -- III
        (h_cnt >= H_DISPLAY - H_DISPLAY/3/2 - 3 and h_cnt < H_DISPLAY - H_DISPLAY/3/2 and v_cnt >= 10 and v_cnt < 25) or
        (h_cnt >= H_DISPLAY - H_DISPLAY/3/2 - 8 and h_cnt < H_DISPLAY - H_DISPLAY/3/2 - 5 and v_cnt >= 10 and v_cnt < 25) or
        (h_cnt >= H_DISPLAY - H_DISPLAY/3/2 + 2 and h_cnt < H_DISPLAY - H_DISPLAY/3/2 + 5 and v_cnt >= 10 and v_cnt < 25)  or
        --separator between sections
        (h_cnt = H_DISPLAY/3) or (h_cnt = 2*H_DISPLAY/3)
         then -- black
            vgaRed_reg_next <= X"0";
            vgaGreen_reg_next <= X"0";
            vgaBlue_reg_next <= X"0";
        end if;
    end process;

    hsync_vsync: process(pix_clock, sresetn, h_cnt, v_cnt)
    begin
        if (sresetn = '1') then
            h_cnt <= to_unsigned(0, h_cnt'length);
            v_cnt <= to_unsigned(0, v_cnt'length);
        elsif rising_edge(pix_clock) then
            if (h_cnt < H_TOTAL - 1) then
                h_cnt <= h_cnt + 1;
            else 
                h_cnt <= to_unsigned(0, h_cnt'length);
                if (v_cnt < V_TOTAL - 1) then 
                    v_cnt <= v_cnt + 1;
                else 
                    v_cnt <= to_unsigned(0, v_cnt'length);
                end if;
            end if;
        end if;
    end process;
    
    Hsync <= '0' when h_cnt >= (H_DISPLAY + H_FRONT_PORCH) and h_cnt < (H_DISPLAY + H_FRONT_PORCH + H_SYNC_PULSE) else '1';
    Vsync <= '0' when v_cnt >= (V_DISPLAY + V_FRONT_PORCH) and v_cnt < (V_DISPLAY + V_FRONT_PORCH + V_SYNC_PULSE) else '1';
    vgaRed <= vgaRed_reg;
    vgaGreen <= vgaGreen_reg;
    vgaBlue <= vgaBlue_reg;
end Behavioral;