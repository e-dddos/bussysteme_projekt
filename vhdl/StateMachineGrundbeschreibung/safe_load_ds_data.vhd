library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity safe_load_ds_data is
    generic ( N_LENGTH : natural := 64);    
    Port ( clk : in STD_LOGIC;
           sresetn : in STD_LOGIC;
           save : in STD_LOGIC;
           en_in : in STD_LOGIC;
           data_in : in STD_LOGIC;
           led_debug_out : out STD_LOGIC);
           -- reg_out : out STD_LOGIC_VECTOR (N_LENGTH-1 downto 0);
           -- reg_rdy : out STD_LOGIC);
end safe_load_ds_data;

architecture Inout_Data_Handling of safe_load_ds_data is

signal input_buffer, input_buffer_next: STD_LOGIC_VECTOR (N_LENGTH-1 downto 0);

begin

get_data: process (clk, en_in, data_in, sresetn)
begin
    led_debug_out <= en_in;
    if rising_edge(en_in) then
        input_buffer <= input_buffer(N_LENGTH-2 downto 0) & data_in;
    end if;
    if sresetn='1' then
        input_buffer <= (others => '0');
        --reg_out <= (others => '0');        
    elsif rising_edge(clk) then
--        if en_in = '1' then
--            input_buffer <= input_buffer(N_LENGTH-2 downto 0) & data_in;
            --reg_rdy <= '0';
        if save = '1' then
            --reg_out <= input_buffer;
        --elsif (en_in = '0' and save = '1') then
            led_debug_out <= input_buffer(N_LENGTH-1);
            input_buffer <= input_buffer(N_LENGTH-2 downto 0) & '0';
        else 
            led_debug_out <= en_in;
            --reg_rdy <= '1';
        end if;
    end if;

end process get_data;

end Inout_Data_Handling;
