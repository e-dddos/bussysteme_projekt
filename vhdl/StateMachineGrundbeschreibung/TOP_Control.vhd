library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity TOP_Control is
    port (  MHZ100 : in STD_LOGIC;
            DQ : inout STD_LOGIC;
            RES_IN : in STD_LOGIC;
            LED_0_DEBUG : out STD_LOGIC);
end TOP_Control;

architecture Mapping of TOP_Control is

component DS18B20
port(
    clk : in STD_LOGIC;
    sresetn : in STD_LOGIC;
    ds_data_safe : out STD_LOGIC;
    ds_data_bus : inout STD_LOGIC;
    en_output : out STD_LOGIC;
    en_safe : out STD_LOGIC
    );
end component;
    
component clk_division
port(
    clk_in : in STD_LOGIC;
    clk_out : out STD_LOGIC
    );
end component;

component safe_load_ds_data
port(
    clk : in STD_LOGIC;
    sresetn : in STD_LOGIC;
    save : in STD_LOGIC;
    en_in : in STD_LOGIC;
    data_in : in STD_LOGIC;
    led_debug_out : out STD_LOGIC
    );
end component;

signal CLK1MHZ : STD_LOGIC;
signal DATA : STD_LOGIC;
signal EN_DATA : STD_LOGIC;
signal EN_SAFING : STD_LOGIC;

begin

U1: clk_division port map(
    clk_in => MHZ100,
    clk_out => CLK1MHZ
    );

U2: DS18B20 port map(
    clk => CLK1MHZ,
    sresetn => RES_IN,
    ds_data_safe => DATA,
    ds_data_bus => DQ,
    en_output => EN_DATA,
    en_safe => EN_SAFING
    );

    
U3: safe_load_ds_data port map(
    clk => CLK1MHZ,
    sresetn => RES_IN,
    save => EN_SAFING,
    en_in => EN_DATA,
    data_in => DATA,
    led_debug_out => LED_0_DEBUG
    );
    
end Mapping;