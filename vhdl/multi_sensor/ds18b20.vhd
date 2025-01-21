----------------------------------------------------------------------------------
-- University: HAW Hamburg
-- Engineer(s): Valentin Kniesel, Eduard Lomtadze, Uwe Scharnweber : Students
-- 
-- Create Date: 2025
-- Design Name: Dynamic 1-Wire Multi DS18B20 Processing (With simple VGA output)
-- Module Name: DS18B20 - Top controll to handle 1-Wire bus. IO for data and 
--              addresses. Main state logic and device detection.
-- Project Name: 1-Wire-Bus with DS18B20 Temp Sensor
-- Target Devices: Created on Artix 7 xc7a35tcpg236-1, Basys 3 Board
-- Tool Versions: Vivado 2024.1/2024.2
-- Description: This project handles the temperature data, delivered by multiple
--              1-Wire-Devices (DS18B20). The sensors can be added and removed
--              from the bus at any time. The bus server will register changes on
--              the bus. The time it needs for that can be changed.
--              The temperature data is shown on the 7-Segment-Display of the 
--              Basys 3 and on a VGA-Display, if connected. The constraints for
--              the display need to be changed according to the device used.
--              Right now upto 4 sensor addresses can be read in and 3 are
--              processed.
--
-- Revision 0.01 - File Created
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DS18B20 is
    generic(
        N_BIT   : NATURAL := 1024;    -- Telegram length
        BIT_64  : NATURAL := 64;      -- Scratchpad and Address
        MAX_SENS: NATURAL := 4;       -- Maximum amount of DS18B20s
        N_COM   : NATURAL := 7;       -- Command bit interate
        NORUNS  : NATURAL := 2;       -- Number of runs
        N_COUNT : NATURAL := 799999); -- Iterator
    Port(   
        clk           : in    STD_LOGIC;    -- Clock input (1MHz)
        sresetn       : in    STD_LOGIC;    -- Reset with button BTNC U18
        data_out      : out   STD_LOGIC;    -- Data throuput to data handling
        ds_data_bus   : inout STD_LOGIC;    -- DQ pin input/output
        en_bit_out    : out   STD_LOGIC;    -- Enable data to storage
        en_addr_search: out   STD_LOGIC;    -- Enable search rom storage
        en_store      : out   STD_LOGIC;    -- Enable data package complete
        -- Address input/output
        en_addr_new   : out   STD_LOGIC;    -- new address read or write
        addr_in       : in    STD_LOGIC_VECTOR (BIT_64-1 downto 0);
        addr_out      : out   STD_LOGIC_VECTOR (BIT_64-1 downto 0);
        -- Address register selection
        addr_sel_out  : out   STD_LOGIC_VECTOR (1 downto 0)
    );
end DS18B20;

architecture Behavioral of DS18B20 is

-- FSM states
type STATE_TYPE      is (RESET, SEARCH_ADDRESS, WRITE_COMMAND, WRITE_ADDRESS, READ_BUS, TEMP_CONVERSION_TIME, 
                         CLEAR_ADDRESS);
type S_SUB_RESET     is (RSET_LOW, RSET_RELEASE, RSET_PRESENCE_PULSE, RSET_START_END);
--type S_SUB_SEARCH    is (SEARCH_COM, SEARCH_ADDR_READ);
type S_SUB_MATCHING  is (BIT_GET_NORMAL, BIT_GET_COMPLEMENT, BIT_SET_DIRECTION, BIT_STORE_ADDRESS);
-- Command states ROM and Function
type STATE_ROM  is (MTCH55H, SRCHF0H);
type STATE_FUNC is (CONV44H, RDSCBEH);

-- Signal state registers
signal s, s_next: STATE_TYPE := RESET;
-- Substate initialization
signal s_res, s_res_next           : S_SUB_RESET    := RSET_LOW;
--signal s_search, s_search_next     : S_SUB_SEARCH   := SEARCH_COM;
signal s_matching, s_matching_next : S_SUB_MATCHING := BIT_GET_NORMAL;
signal s_rom, s_rom_next           : STATE_ROM      := SRCHF0H;
signal s_func, s_func_next         : STATE_FUNC     := CONV44H;
-- Counters
signal i            : INTEGER RANGE 0 TO N_COUNT;
signal i_reset      : STD_LOGIC;
signal k            : INTEGER RANGE 0 TO N_BIT := 0;
signal k_next       : INTEGER RANGE 0 TO 2 := 1; -- 0=nothing, 1=new value(+1), 2=reset
signal runs, r_next : INTEGER RANGE 0 TO 100 := 0;
-- Data bus signals
signal ds, ds_out, ds_out_next, ds_presence, ds_presence_next, addr_old_update, addr_search_update, addr_update, 
       en_ds, en_ds_next : STD_LOGIC;
signal com, com_next     : STD_LOGIC_VECTOR (N_COM downto 0):=x"55";
-- Search process signals
signal addr_search, addr, addr_old, addr_sel : STD_LOGIC_VECTOR (BIT_64-1 downto 0) := (others => '0');
constant ADDR_EMPTY   : STD_LOGIC_VECTOR (BIT_64-1 downto 0) := (others => '0');
signal last_device_check, last_device_check_next : INTEGER range 0 to MAX_SENS-1 := 0;
signal current_device, current_device_next       : INTEGER range 0 to MAX_SENS-1 := 0;
signal bit_normal, bit_normal_next, bit_complement, bit_complement_next, bit_direction, bit_direction_next : STD_LOGIC;
signal search_bit, search_bit_next, last_discrepancy, last_discrepancy_next : INTEGER range 0 to BIT_64 := 0;

begin
-------------------------------------------------------------------------------------------------------------
    -- Three-state buffer for data bus
    ds_data_bus <= ds_out when en_ds = '1' else 'Z';
-------------------------------------------------------------------------------------------------------------
FSM_Driver: process(clk, s, s_res, s_rom, s_func, ds_data_bus, ds, com, i, k, search_bit, addr, addr_search,
                    addr_update, en_ds, s_matching, ds_presence, bit_normal, bit_complement, bit_direction, ds_out, 
                    last_discrepancy, current_device, last_device_check, addr_old, runs, addr_in, addr_sel)
begin
    -- default states
    s_next          <= s;
    s_res_next      <= s_res;
    s_rom_next      <= s_rom;
    s_func_next     <= s_func;
    s_matching_next <= s_matching;
    -- default values
    addr_out            <= addr;
    en_bit_out          <= '0';
    en_addr_search      <= '0';
    en_ds_next          <= en_ds;
    ds_out_next         <= ds_out;
    ds_presence_next    <= ds_presence;
    en_store            <= '0';
    en_addr_new         <= '0';
    i_reset             <= '0';
    k_next              <= 0;
    addr_update         <= '0';
    addr_search_update  <= '0';
    addr_old_update     <= '0';
    com_next            <= com;
    r_next              <= runs;
    bit_normal_next     <= bit_normal;
    bit_complement_next <= bit_complement;
    bit_direction_next  <= bit_direction;
    search_bit_next     <= search_bit;
    last_discrepancy_next  <= last_discrepancy;
    current_device_next    <= current_device;
    last_device_check_next <= last_device_check;
    -------------------------------------------------------------------------------------------------------------
    -- FSM
    case s is
        -- State for starting sequence
        when RESET =>
            case s_res is
                -- Force low to start sequence
                when RSET_LOW =>
                    k_next <= 2;
                    en_ds_next <= '1'; -- force low
                    ds_out_next <= '0';
                    if (i = 484) then
                        s_res_next <= RSET_RELEASE;
                    end if;
                -- Release and wait for presence pulse
                when RSET_RELEASE =>
                    en_ds_next <= '0';
                    if (i = 569) then
                        s_res_next <= RSET_PRESENCE_PULSE;
                    end if;
                -- Presence detection
                when RSET_PRESENCE_PULSE =>
                    if (i = 570) then
                        ds_presence_next <= ds;
                    elsif (i = 999) then
                        s_res_next <= RSET_START_END;
                    end if;
                -- Change to next state depending on ROM command
                when RSET_START_END =>
                    i_reset <= '1';
                    s_res_next <= RSET_LOW;
                    if (ds_presence = '0' and ds = '1') then
                        s_next <= WRITE_COMMAND;
                        -- ROM COMMANDS --
                        case s_rom is
                            when MTCH55H => -- match rom command
                                com_next <= x"55";
                            when SRCHF0H => -- search rom command
                                com_next <= x"F0";
                        end case;
                    -- Something went wrong
                        else
                            s_next     <= TEMP_CONVERSION_TIME;
                            s_res_next <= RSET_LOW;
                            s_rom_next <= SRCHF0H;
                        end if;
                    when others=>
                        s_res_next <= RSET_LOW;
                        s_next     <= RESET;
                        s_rom_next <= SRCHF0H;
            end case;
    -------------------------------------------------------------------------------------------------------------
        when SEARCH_ADDRESS =>
            -- Receive normal and complement bit, set bit direction and match
            case s_matching is
                -- Read bit value
                when BIT_GET_NORMAL =>
                    if i < 3 then
                        en_ds_next <= '1';
                        ds_out_next <= '0';
                    elsif i < 4 then
                        en_ds_next <= '0';
                    elsif i = 14 then
                        bit_normal_next <= ds;
                    elsif i = 59 then
                        s_matching_next <= BIT_GET_COMPLEMENT;
                        i_reset <= '1';
                    end if;
                -- Read complement bit value
                when BIT_GET_COMPLEMENT =>
                    if i < 3 then
                        en_ds_next <= '1';
                        ds_out_next <= '0';
                    elsif i < 4 then
                        en_ds_next <= '0';
                    elsif i = 14 then
                        bit_complement_next <= ds;
                    elsif i = 59 then
                        s_matching_next <= BIT_SET_DIRECTION;
                        i_reset <= '1';
                        -- Set bit direction
                        -- Only 0s
                        if bit_normal = '0' and bit_complement = '1' then
                            bit_direction_next <= '0';
                        -- Only 1s
                        elsif bit_normal = '1' and bit_complement = '0' then
                            bit_direction_next <= '1';
                        -- Discrepancy (0s and 1s on bus)
                        elsif bit_normal = '0' and bit_complement = '0' then
                            -- old path
                            if last_discrepancy > search_bit then
                                bit_direction_next <= addr_old(search_bit);
                            -- 1s path
                            elsif last_discrepancy = search_bit then
                                bit_direction_next <= '1';
                            -- 0s path
                            else
                                bit_direction_next <= '0';
                                last_discrepancy_next <= search_bit;
                            end if;
                        -- No device(s) on bus
                        elsif bit_normal = '1' and bit_complement = '1' then
                            s_next                 <= RESET;
                            s_res_next             <= RSET_LOW;
                            i_reset                <= '1';
                            search_bit_next        <= 0;
                            last_device_check_next <= 0;
                            current_device_next    <= 0;
                        end if;
                    end if;
                -- Set bit direction and match
                when BIT_SET_DIRECTION =>
                    en_addr_search <= '1';
                    -- Bitstart with 0
                    if (i < 5) then
                        en_ds_next  <= '1';
                        ds_out_next <= '0';
                    -- Bit either 0 or 1 (Z)
                    elsif (i < 60) then
                        -- output keeps low if bit is 0 else release
                        if bit_direction = '1' then
                            en_ds_next <= '0';
                        end if;
                    elsif (i = 61) then
                        en_ds_next         <= '0';
                        addr_search_update <= '1'; -- Update current search address
                    elsif (i = 64) then
                        i_reset <= '1';
                        if search_bit = BIT_64-1 then
                            search_bit_next <= 0;
                        -- Check if done
                            -- done
                            if addr_search = addr_old then
                                last_device_check_next <= last_device_check - 1;
                                current_device_next    <= 0;
                                last_discrepancy_next  <= 0;
                                search_bit_next        <= 0;
                                s_rom_next             <= MTCH55H;
                                s_res_next             <= RSET_LOW;
                                s_next                 <= RESET;
                            -- not done
                            else
                                s_matching_next <= BIT_STORE_ADDRESS;
                            end if;
                        else
                            s_matching_next <= BIT_GET_NORMAL;
                            search_bit_next <= search_bit + 1;
                        end if;
                    end if;
                when BIT_STORE_ADDRESS =>
                -- Prepare for next device
                    en_addr_search <= '1';
                    if (i < 2) then
                        en_addr_new <= '1';
                    else
                        s_res_next      <= RSET_LOW;
                        s_next          <= RESET;
                        i_reset         <= '1';
                        addr_old_update <= '1'; 
                        if (last_device_check < MAX_SENS-1) then
                            last_device_check_next <= last_device_check + 1;
                            current_device_next    <= last_device_check + 1;   
                        else
                            last_discrepancy_next <= 0;
                            current_device_next   <= 0;
                            s_rom_next            <= MTCH55H; 
                        end if;
                    end if;
                end case;
    -------------------------------------------------------------------------------------------------------------
        when WRITE_COMMAND => -- Either ROM or function command
            -- Bitstart with 0
            if (i < 5) then
                en_ds_next  <= '1';
                ds_out_next <= '0';
            -- Bit either 0 or 1 (Z)
            elsif (i < 60) then
                if com(k) = '0' then
                    ds_out_next <= '0';
                else
                    en_ds_next <= '0';
                end if;
            -- Bitend with 1 (Z), update to next client address
            elsif (i < 64) then
                en_ds_next  <= '0';
                en_addr_new <= '1';
            elsif (i = 64) then
                i_reset <= '1';
                k_next  <= 1;
                if k = 7 then
                    k_next <= 2;
                    -- next after ROM cmd
                    if com = x"F0" then
                        s_next          <= SEARCH_ADDRESS;
                        s_matching_next <= BIT_GET_NORMAL;
                    elsif com = x"55" then -- match rom
                        s_next      <= WRITE_ADDRESS;
                        addr_update <= '1';
                    -- next after FUNC cmd
                    elsif com = x"BE" then -- read scratchpad
                        s_next     <= READ_BUS;
                        s_rom_next <= MTCH55H;
                    elsif com = x"44" then -- convert t
                        s_next     <= TEMP_CONVERSION_TIME;
                        s_rom_next <= MTCH55H;
                    end if;
                end if;
            end if;
    -------------------------------------------------------------------------------------------------------------
        when WRITE_ADDRESS => -- Call specific device
            -- Bitstart with 0
            if (i < 5) then
                en_ds_next  <= '1';
                ds_out_next <= '0';
            -- Bit either 0 or 1 (Z)
            elsif (i < 60) then
                if addr_sel(k) = '0' then
                    ds_out_next <= '0';
                else
                    en_ds_next <= '0';
                end if;
            -- Bitend with 1 (Z)
            elsif (i < 64) then
                en_ds_next <= '0';
            elsif (i = 64) then
                i_reset <= '1';
                k_next <= 1;
                -- Prepare next commands
                if k = 63 then
                    k_next <= 2;
                    s_next <= WRITE_COMMAND;
                    if s_func = CONV44H then
                        s_func_next <= RDSCBEH;
                        com_next <= x"BE";
                    else
                        s_func_next <= CONV44H;
                        com_next <= x"44";
                    end if;
                end if;
            end if;
    -------------------------------------------------------------------------------------------------------------
        when READ_BUS =>
            if i < 3 then
                en_ds_next  <= '1';
                ds_out_next <= '0';
            elsif i < 4 then
                en_ds_next <= '0';
            elsif i = 14 then
                --data_out <= ds;
                en_bit_out <= '1';
            elsif i = 59 then
                i_reset <= '1';
                k_next  <= 1;
                -- End of read cycle and next state
                -- Full reset after NORUNS-1: All addresses are read again
                if (k = BIT_64 - 1) then
                    k_next <= 2;
                    if com = "10111110" then
                        en_store <= '1';
                    end if;
                    if current_device < last_device_check then
                        current_device_next <= current_device + 1;
                        s_next              <= RESET;
                        s_res_next          <= RSET_LOW;
                    elsif runs < NORUNS-1 then
                        r_next              <= runs + 1;
                        current_device_next <= 0;
                        s_next              <= RESET;
                        s_res_next          <= RSET_LOW;
                    else
                        s_next  <= CLEAR_ADDRESS;
                        i_reset <= '1';
                    end if;
                end if;
            end if;
    -------------------------------------------------------------------------------------------------------------
        -- Hold 1 for the conversion of the temperature of selected device
        when TEMP_CONVERSION_TIME =>
            if (i < 750000) then
                ds_out_next <= '1';
                en_ds_next  <= '1';
            else
                s_next     <= RESET;
                s_res_next <= RSET_LOW;
                i_reset    <= '1';
            end if;
    -------------------------------------------------------------------------------------------------------------
        -- Clear all addresses and reset if NORUNS-1 is reached
        when CLEAR_ADDRESS =>
            en_addr_search <= '1';
            addr_out <= ADDR_EMPTY;
            en_addr_new <= '1';
            if i = 1 then
                current_device_next <= 0;
            elsif i = 3 then
                current_device_next <= 1;
            elsif i = 5 then
                current_device_next <= 2;
            elsif i = 7 then
                current_device_next <= 3;
            elsif i = 9 then
                last_device_check_next <= 0;
                current_device_next    <= 0;
                last_discrepancy_next  <= 0;
                s_next     <= RESET;
                s_res_next <= RSET_LOW;
                s_rom_next <= SRCHF0H;
                i_reset    <= '1';
                r_next     <= 0;
            end if;
    -------------------------------------------------------------------------------------------------------------
        when others =>
            s_res_next <= RSET_LOW;
            s_next     <= RESET;
    end case;
end process FSM_Driver;
    -------------------------------------------------------------------------------------------------------------
-- State transition control with reset
state_control: process (clk, sresetn)
begin
    if (rising_edge(clk)) then
        if (sresetn = '0') then
            -- States
            s          <= s_next;
            s_res      <= s_res_next;
            s_rom      <= s_rom_next;
            s_func     <= s_func_next;
            s_matching <= s_matching_next;
            -- Data signal logic
            ds                <= ds_data_bus;
            data_out          <= ds;
            runs              <= r_next;
            com               <= com_next;
            ds_presence       <= ds_presence_next;
            en_ds             <= en_ds_next;
            bit_normal        <= bit_normal_next;
            bit_complement    <= bit_complement_next;
            bit_direction     <= bit_direction_next;
            search_bit        <= search_bit_next;
            last_discrepancy  <= last_discrepancy_next;
            current_device    <= current_device_next;
            last_device_check <= last_device_check_next;
            ds_out            <= ds_out_next;
            if current_device = 0 then
                addr_sel_out <= "00";
            elsif current_device = 1 then
                addr_sel_out <= "01";
            elsif current_device = 2 then
                addr_sel_out <= "10";
            elsif current_device = 3 then
                addr_sel_out <= "11";
            end if;
        else
            s     <= RESET;
            s_res <= RSET_LOW;
            s_rom <= SRCHF0H;
            search_bit        <= 0;
            last_discrepancy  <= 0;
            last_device_check <= 0;
            current_device    <= 0;
        end if;
    end if;
end process state_control;
    -------------------------------------------------------------------------------------------------------------
-- Counting and reset control
iterate_control: process(clk, i_reset, k_next, sresetn)
begin
	if (rising_edge(clk)) then
	    -- counting and count reset, state resets
		if (i_reset = '1')then
			i <= 0;
		else
			i <= i + 1;
		end if;
        if(k_next = 1) then
            k <= k + 1;
        elsif (k_next = 2) then
            k <= 0;
        end if;
	end if;
end process iterate_control;
    -------------------------------------------------------------------------------------------------------------
-- Synchronous data/pin managment
ds_data_throughput: process(clk)
begin
    if (rising_edge(clk)) then
        -- update addr register (for commands)
        if addr_update = '1' then
            addr_sel <= addr_in;
        end if;
        -- update addr searching register
        if addr_search_update = '1' then
            addr_search <= bit_direction & addr_search(BIT_64-1 downto 1);
        else
            addr <= addr_search;
        end if;
        -- update addr old register
        if addr_old_update = '1' then
            addr_old <= addr;
        elsif s = WRITE_ADDRESS then
            addr_old <= ADDR_EMPTY;
        end if;
    end if;
end process ds_data_throughput;

end Behavioral;