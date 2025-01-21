----------------------------------------------------------------------------------
-- University: HAW Hamburg
-- Engineer(s): Valentin Kniesel, Eduard Lomtadze, Uwe Scharnweber : Students
-- 
-- Create Date: 2025
-- Design Name: Dynamic 1-Wire Multi DS18B20 Processing (With simple VGA output)
-- Module Name: Safe-Load-DS-Data - This module handles the Data and Addresses send
--              to it by the DS18B20 module. When new temperature data for a sensor
--              are ready, it transmits the data and selected sensor to submodules.
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

entity safe_load_ds_data is
    generic ( 
        BIT_64      : natural := 64;
        TEMP_LENGTH : natural := 16);   
    Port ( 
        clk              : in  STD_LOGIC;   -- 1 MHz clock
        en_store         : in  STD_LOGIC;   -- Enable to store serial data
        en_in            : in  STD_LOGIC;   -- Enable to read serial data
        data_in          : in  STD_LOGIC;   -- Serial data input
        en_addr_search   : in  STD_LOGIC;   -- Enable to store '1' or read '0' address
        led_debug_out    : out STD_LOGIC;   -- Output for oszilloscope visualization
        reg_rdy          : out STD_LOGIC;   -- Ready signal for parallel temp-data output
        en_addr_out      : in  STD_LOGIC;   -- Enable to read and store address
        addr_sel_in      : in  STD_LOGIC_VECTOR (1 downto 0);           -- Select address to store/read
        addr_sel_vis     : out STD_LOGIC_VECTOR (1 downto 0);           -- Current device with temp-data
        addr_in          : in  STD_LOGIC_VECTOR (BIT_64-1 downto 0);    -- Address input
        addr_out         : out STD_LOGIC_VECTOR (BIT_64-1 downto 0);    -- Address output
        temp_out         : out STD_LOGIC_VECTOR (TEMP_LENGTH-1 downto 0)-- Parallelized temp output
        );
end safe_load_ds_data;

architecture Inout_Data_Handling of safe_load_ds_data is
-- Signals for data handling
signal input_buffer   : STD_LOGIC_VECTOR (BIT_64-1 downto 0);
signal input_buffer_2 : STD_LOGIC_VECTOR (BIT_64-1 downto 0);
-- Signals for address handling (multiple addresses)
signal input_address_storage_0 : STD_LOGIC_VECTOR (BIT_64-1 downto 0) := (others => '0');
signal input_address_storage_1 : STD_LOGIC_VECTOR (BIT_64-1 downto 0) := (others => '0');
signal input_address_storage_2 : STD_LOGIC_VECTOR (BIT_64-1 downto 0) := (others => '0');
signal input_address_storage_3 : STD_LOGIC_VECTOR (BIT_64-1 downto 0) := (others => '0');

begin

temperature_data: process (clk, en_in, en_store, data_in, en_addr_search, addr_sel_in, en_addr_out)
VARIABLE zeros : std_logic_vector (BIT_64-1 downto 0) := (others => '0');
begin
    -- reading temperature data
    if rising_edge(clk) and en_in = '1' then
        input_buffer <= data_in & input_buffer(BIT_64-1 downto 1);
    end if;
    -- saving temperature data
    if rising_edge(clk) then
        if en_store = '1' then
            temp_out <= input_buffer(TEMP_LENGTH-1 downto 0);
            addr_sel_vis <= addr_sel_in;
            reg_rdy <= '1';
            
        else -- temporary data output
            reg_rdy <= '0';
            led_debug_out <= input_buffer_2(BIT_64-1);
            input_buffer_2 <= input_buffer_2(BIT_64-2 downto 0) & '0';
        end if;
    -- reading and storing addresses depending on en_addr_search
        -- storing addresses
        if en_addr_search = '1' and en_addr_out = '1' then
            if addr_sel_in    = "00" then
                input_address_storage_0 <= addr_in;
                if addr_in = zeros then
                    temp_out <= x"0000";
                    addr_sel_vis <= addr_sel_in;
                end if;
            elsif addr_sel_in = "01" then
                input_address_storage_1 <= addr_in;
                if addr_in = zeros then
                    temp_out <= x"0000";
                    addr_sel_vis <= addr_sel_in;
                end if;
            elsif addr_sel_in = "10" then
                input_address_storage_2 <= addr_in;
                if addr_in = zeros then
                    temp_out <= x"0000";
                    addr_sel_vis <= addr_sel_in;
                end if;
            elsif addr_sel_in = "11" then
                input_address_storage_3 <= addr_in;
                if addr_in = zeros then
                    temp_out <= x"0000";
                    addr_sel_vis <= addr_sel_in;
                end if;
            end if;
        -- reading addresses
        elsif en_addr_search = '0' then
            case addr_sel_in is 
                when "00" =>
                    if (input_address_storage_0 /= zeros) then
                        addr_out <= input_address_storage_0;
                        else
                            addr_out <= zeros;
                    end if;
                when "01" =>
                    if (input_address_storage_1 /= zeros) then
                        addr_out <= input_address_storage_1;
                        else
                        addr_out <= zeros;
                    end if;
                when "10" =>
                    if (input_address_storage_2 /= zeros) then
                        addr_out <= input_address_storage_2;
                        else
                        addr_out <= zeros;
                    end if;
                when "11" =>
                    if (input_address_storage_3 /= zeros) then
                        addr_out <= input_address_storage_3;
                        else
                        addr_out <= zeros;
                    end if;
            end case;
        end if;
    end if;
end process temperature_data;



end Inout_Data_Handling;
