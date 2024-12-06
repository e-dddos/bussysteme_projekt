library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DS18B20 is
    generic(N_BIT : natural := 1024;       -- Telegram length
            N_COM: natural := 7;           -- Command bit interate
            N_COUNT: natural := 799999);   -- Iterator
    Port(   clk : in STD_LOGIC;            -- Clock input (1MHz)
            sresetn : in STD_LOGIC;        -- Reset with button BTNC U18
            ds_data_safe : out STD_LOGIC;  -- Data throuput to data handling
            ds_data_bus : inout STD_LOGIC; -- DQ pin input/output
            en_output : out STD_LOGIC;     -- Enable data to storage
            en_safe : out STD_LOGIC);      -- Enable data package complete
end DS18B20;

architecture Behavioral of DS18B20 is

-- FSM states
type STATE_TYPE is      (RESET, WAIT_100MS, TEST_COMM, TEST_READ);
-- FSM substates
type S_SUB_RESET is     (RSET_LOW, RSET_RELEASE, RSET_PRESENCE_PULSE, RSET_START_END);
type S_SUB_WRITE_OUT is (OUT_WRITE_0_TS, OUT_WRITE_0_RC, OUT_WRITE_1_TS, OUT_WRITE_1_RC);
type S_SUB_READ_IN is   (IN_INIT_READ, IN_EXEC_READ);
-- Command states ROM and Function
type STATE_ROM is  (READ33H, MTCH55H, SKIPCCH, SRCHF0H);
type STATE_FUNC is (CONV44H, WRSC4EH, RDSCBEH);

-- Signal state registers
signal s, s_next: STATE_TYPE; -- Controll for main steps
-- Substate initialization
signal s_res, s_res_next: S_SUB_RESET;
signal s_out, s_out_next:S_SUB_WRITE_OUT;
signal s_in, s_in_next: S_SUB_READ_IN;
signal s_rom, s_rom_next: STATE_ROM;
signal s_func, s_func_next: STATE_FUNC;
-- RESET, data bus
signal clk_reset, ds, ds_data_in, ds_data_bus_next, en_ds, s_en_output, s_en_output_next, s_safe_data, s_safe_data_next: STD_LOGIC;
-- Counter for delay/waiting/probes
signal i: INTEGER RANGE 0 TO N_COUNT;
signal k: INTEGER RANGE 0 TO N_BIT:= 0;
signal k_next: INTEGER RANGE 0 TO 2:= 1; -- 0=
--signal m: INTEGER RANGE 0 TO 20:= 0;
signal com: STD_LOGIC_VECTOR (N_COM downto 0):="00000000";

begin
-------------------------------------------------------------------------------------------------------------
FSM_Driver: process(clk, s, s_res, s_out, s_in, s_rom, ds_data_bus, ds, ds_data_in, com, i, k)
--constant COM33H: STD_LOGIC_VECTOR(7 downto 0):="00110011";
begin
    -- default
    -- keep states
    s_next <= s;
    s_res_next <= s_res;
    s_out_next <= s_out;
    s_in_next <= s_in;
    s_rom_next <= s_rom;                -- keep comm selected
    ds_data_bus_next <= ds_data_bus;    -- keep output
    en_ds <= '1';                       -- keep output enabled
    s_en_output_next <= '0';
    s_safe_data_next <= '0';
    clk_reset <= '0';                   -- cnt up
    k_next <= 0;
    -------------------------------------------------------------------------------------------------------------
    -- FSM
    case s is
        -- State for starting sequence, Ping Pong
        when RESET =>
            case s_res is
                when RSET_LOW =>
                    ds_data_bus_next <= '0';
                    if (i = 484) then
                        en_ds <= '0';
                        s_res_next <= RSET_RELEASE;
                    end if;
                when RSET_RELEASE =>
                    en_ds <= '0';
                    if (i = 569) then
                        s_res_next <= RSET_PRESENCE_PULSE;
                    end if;
                when RSET_PRESENCE_PULSE =>
                    en_ds <= '0';
                    if (i = 570) then
                        ds <= ds_data_in;
                    elsif (i = 999) then
                        s_res_next <= RSET_START_END;
                        s_rom_next <= READ33H;
                        --s_rom_next <= SRCHF0H;
                    end if;
                when RSET_START_END =>
                    clk_reset <= '1';
                    s_res_next <= RSET_LOW;
                    if (ds = '0' and ds_data_bus = '1') then
                        s_next <= TEST_COMM;
                        --s_next <= RESET;
                        case s_rom is
                        -- ROM COMMANDS --
                            when READ33H => -- read rom command
                                com <= "00110011";
                                s_out_next <= OUT_WRITE_1_RC;
                            when SKIPCCH => -- skip rom command
                                com <= "11001100";
                                s_out_next <= OUT_WRITE_0_TS;
                            when MTCH55H => -- skip rom command
                                com <= "01010101";
                                s_out_next <= OUT_WRITE_1_RC;
                            when SRCHF0H => -- skip rom command
                                com <= "11110000";
                                s_out_next <= OUT_WRITE_0_TS;
                        -- FUNCTION COMMANDS --
--                            when CONV44H => -- convert t func. command
--                                com <= "01000100";
--                                s_out_next <= WRITE_0_TS;
--                            when WRSC4EH => -- write scratchpad func. command
--                                com <= "01001110";
--                                s_out_next <= WRITE_0_TS;
--                            when RDSCBEH => -- read scratchpad func. command
--                                com <= "10111110";
--                                s_out_next <= WRITE_0_TS;
                        end case;
                    else
                        s_next <= WAIT_100MS;
                        s_res_next <= RSET_LOW;
                    end if;
                when others=>
                    s_res_next <= RSET_LOW;
                    s_next <= RESET;
            end case;
        -------------------------------------------------------------------------------------------------------------
        when TEST_COMM =>
            case s_out is            
            -- WRITE 0 SEQUENCE
                when OUT_WRITE_0_TS =>
                    ds_data_bus_next <= '0';
                    if (i = 60) then
                        s_out_next <= OUT_WRITE_0_RC;
                    end if;
                when OUT_WRITE_0_RC =>
                    en_ds <= '0'; -- release bus for recov.
                    if (i = 65) then
                        clk_reset <= '1';
                        k_next <= 1;
                        if (com(k) = '0' and k <= 7) then
                            s_out_next <= OUT_WRITE_0_TS;
                        elsif (com(k) = '1' and k <= 7) then
                            s_out_next <= OUT_WRITE_1_RC;
                        else
                            k_next <= 2;
                            s_next <= TEST_READ;
                            s_in_next <= IN_INIT_READ;
                        end if;
                    end if;            
            -- WRITE 1 SEQUENCE
                when OUT_WRITE_1_RC =>
                    ds_data_bus_next <= '0';
                    if (i = 5) then
                        s_out_next <= OUT_WRITE_1_TS;
                    end if;
                when OUT_WRITE_1_TS =>
                    en_ds <= '0'; -- release bus for '1'
                    if (i = 65) then
                        clk_reset <= '1';
                        k_next <= 1;
                        if (com(k) = '0' and k <= 7) then
                            s_out_next <= OUT_WRITE_0_TS;
                        elsif (com(k) = '1' and k <= 7) then
                            s_out_next <= OUT_WRITE_1_RC;
                        else
                            k_next <= 2;
                            s_next <= TEST_READ;
                            s_in_next <= IN_INIT_READ;
                        end if;
                    end if;
            end case;
        -------------------------------------------------------------------------------------------------------------
        when TEST_READ =>
            case s_in is            
            -- INIT READ TIMESLOT
                when IN_INIT_READ =>
                    ds_data_bus_next <= '0';
                    if (i = 3) then
                        s_in_next <= IN_EXEC_READ;
                        en_ds <= '0';
                    end if;
            -- READ TIMESLOT
                when IN_EXEC_READ =>
                    en_ds <= '0'; -- release bus for recov.
                    if (i = 12) then
                        ds_data_safe <= ds_data_in;
                        s_en_output_next <= '1';
                    elsif (i = 59) then
                        clk_reset <= '1';
                        k_next <= 1;
                        if (k < 64) then
                            s_in_next <= IN_INIT_READ;
                        else
                            k_next <= 2;
                            s_next <= WAIT_100MS;
                            s_res_next <= RSET_LOW;
                        end if;
                    end if;
            end case;
        -------------------------------------------------------------------------------------------------------------
        when WAIT_100MS =>
            s_safe_data_next <= '1';
            if (i < 1000) then
                en_ds <= '0';
            else
                s_next <= RESET;
                clk_reset <= '1';
            end if;
        when others =>
            s_next <= RESET;
    end case;
end process FSM_Driver;
-------------------------------------------------------------------------------------------------------------
-- State transition control with reset
state_control: process (clk, sresetn, s_next, en_ds)
begin
    if (rising_edge(clk)) then
        if (sresetn = '0') then
            s <= s_next;
            s_res <= s_res_next;
            s_out <= s_out_next;
            s_in <= s_in_next;
            s_rom <= s_rom_next;
            s_en_output <= s_en_output_next;
            s_safe_data <= s_safe_data_next;
        else
            s <= RESET;
            s_res <= RSET_LOW;
        end if;
        if(en_ds = '1') then
            ds_data_bus <= ds_data_bus_next;
        else
            ds_data_bus <= 'Z';
        end if;
    end if;
end process state_control;
-------------------------------------------------------------------------------------------------------------
-- Clock counter for timed decisions
iterate_control: process(clk, clk_reset, k_next)
begin
	if (rising_edge(clk)) then
	    -- counting and count reset, state resets
		if (clk_reset = '1')then
			i <= 0;
		else
			i <= i + 1;
		end if;
        if(k_next = 1) then
            k <= k + 1;
        elsif (k_next = 2) then
            k <= 1;
        end if;
	end if;
end process iterate_control;
-------------------------------------------------------------------------------------------------------------
-- Synchronous data input (0, 1, Z, input)
ds_data_throughput: process(en_ds, clk)
begin
    if (rising_edge(clk)) then
        ds_data_in <= ds_data_bus;
        en_output <= s_en_output;
        en_safe <= s_safe_data;
    end if;
end process ds_data_throughput;

end Behavioral;