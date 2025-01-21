----------------------------------------------------------------------------------
-- University: HAW Hamburg
-- Engineer(s): Valentin Kniesel, Eduard Lomtadze, Uwe Scharnweber : Students
-- 
-- Create Date: 2025
-- Design Name: Dynamic 1-Wire Multi DS18B20 Processing (With simple VGA output)
-- Module Name: TOP Control - internal conections for the components and wiring to
--              external pins, switches, buttons, ...
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


entity TOP_Control is
generic ( 
    BIT_64      : NATURAL := 64;    -- 64 Bit for the DS18B20
    TEMP_LENGTH : NATURAL := 16     -- 16 Bit for the temperature
);   
port (  
    MHZ100      : in    STD_LOGIC;  -- Internal 100MHz clock
    DQ          : inout STD_LOGIC;  -- 1-Wire-Bus
    RES_IN      : in    STD_LOGIC;  -- Reset button
    LED_0_DEBUG : out   STD_LOGIC;  -- Visualisation on oscilloscope
    EN_DEC_POINT: out   STD_LOGIC;  -- Decimal point on 7-Segment-Display
    SWITCHES    : in    STD_LOGIC_VECTOR (1 downto 0);  -- Sensor data selection
    EN_7SEG_DIG : out   STD_LOGIC_VECTOR (3 downto 0);  -- 7-Segment-Display EN
    OUTPUT_7SEG : out   STD_LOGIC_VECTOR (6 downto 0);  -- 7-Segment-Display NUM
    -- VGA
    vgaRed      : out   STD_LOGIC_VECTOR (3 downto 0);  -- VGA Red
    vgaGreen    : out   STD_LOGIC_VECTOR (3 downto 0);  -- VGA Green
    vgaBlue     : out   STD_LOGIC_VECTOR (3 downto 0);  -- VGA Blue
    Hsync       : out   STD_LOGIC;  -- VGA Hsync
    Vsync       : out   STD_LOGIC   -- VGA Vsync
    ); 
end TOP_Control;

architecture Mapping of TOP_Control is

component DS18B20
port(
    clk           : in    STD_LOGIC;
    sresetn       : in    STD_LOGIC;
    data_out      : out   STD_LOGIC;
    ds_data_bus   : inout STD_LOGIC;
    en_bit_out    : out   STD_LOGIC;
    en_addr_search: out   STD_LOGIC;
    en_store      : out   STD_LOGIC;
    en_addr_new   : out   STD_LOGIC;
    addr_in       : in    STD_LOGIC_VECTOR (BIT_64-1 downto 0);
    addr_out      : out   STD_LOGIC_VECTOR (BIT_64-1 downto 0);
    addr_sel_out  : out   STD_LOGIC_VECTOR (1 downto 0)
    );
end component;
    
component clk_division
port(
    clk_in  : in  STD_LOGIC;
    clk_out : out STD_LOGIC
    );
end component;

component safe_load_ds_data
Port ( 
    clk              : in  STD_LOGIC;
    en_store         : in  STD_LOGIC;
    en_in            : in  STD_LOGIC;
    data_in          : in  STD_LOGIC;
    en_addr_search   : in  STD_LOGIC;
    led_debug_out    : out STD_LOGIC;
    reg_rdy          : out STD_LOGIC;
    en_addr_out      : in  STD_LOGIC;
    addr_sel_in      : in  STD_LOGIC_VECTOR (1 downto 0);
    addr_sel_vis     : out STD_LOGIC_VECTOR (1 downto 0);
    addr_in          : in  STD_LOGIC_VECTOR (BIT_64-1 downto 0);
    addr_out         : out STD_LOGIC_VECTOR (BIT_64-1 downto 0);
    temp_out         : out STD_LOGIC_VECTOR (TEMP_LENGTH-1 downto 0)
    );
end component;

component vga
port(
    clk            : in  STD_LOGIC;
    sresetn        : in  STD_LOGIC;
    vgaRed         : out STD_LOGIC_VECTOR(3 downto 0);
    vgaGreen       : out STD_LOGIC_VECTOR(3 downto 0);
    vgaBlue        : out STD_LOGIC_VECTOR(3 downto 0);
    Hsync          : out STD_LOGIC;
    Vsync          : out STD_LOGIC;
    tempval_ready  : in  STD_LOGIC;
    sensor_address : in  STD_LOGIC_VECTOR(1 downto 0);
    tempval_in     : in  STD_LOGIC_VECTOR(TEMP_LENGTH-1 downto 0)
    );
end component;

component seven_segment_display
port(
    clk                : in  STD_LOGIC;
    tempval_ready      : in  STD_LOGIC; 
    sresetn            : in  STD_LOGIC;
    sensor_address     : in  STD_LOGIC_VECTOR(1 downto 0);
    sensor_select      : in  STD_LOGIC_VECTOR(1 downto 0);
    tempval_in         : in  STD_LOGIC_VECTOR(TEMP_LENGTH-1 downto 0);
    seven_segments_out : out STD_LOGIC_VECTOR(6 downto 0);
    decimal_point_out  : out STD_LOGIC;
    digit_enable_out   : out STD_LOGIC_VECTOR(3 downto 0)
    );
end component;

signal CLK1MHZ       : STD_LOGIC;
signal DATA_BIT      : STD_LOGIC;
signal EN_DATA       : STD_LOGIC;
signal EN_STORE_DATA : STD_LOGIC;
signal TEMP_DATA     : STD_LOGIC_VECTOR (TEMP_LENGTH-1 downto 0);
signal TEMP_RDY      : STD_LOGIC;
signal EN_ADD_SRCH   : STD_LOGIC;
signal ADDR_DS_STORE : STD_LOGIC_VECTOR (BIT_64-1 downto 0);
signal ADDR_STORE_DS : STD_LOGIC_VECTOR (BIT_64-1 downto 0);
signal ADDR_SEL      : STD_LOGIC_VECTOR (1 downto 0);
signal ADDR_VIS_SEL  : STD_LOGIC_VECTOR (1 downto 0);
signal ADDR_TRANS_EN : STD_LOGIC;

begin

U1: clk_division port map(
    clk_in => MHZ100,
    clk_out => CLK1MHZ
    );

U2: DS18B20 port map(
    clk            => CLK1MHZ,
    sresetn        => RES_IN,
    data_out       => DATA_BIT,
    ds_data_bus    => DQ,
    en_bit_out     => EN_DATA,
    en_addr_search => EN_ADD_SRCH,
    en_store       => EN_STORE_DATA,
    en_addr_new    => ADDR_TRANS_EN,
    addr_in        => ADDR_STORE_DS,
    addr_out       => ADDR_DS_STORE,
    addr_sel_out   => ADDR_SEL
    );
    
U3: safe_load_ds_data port map(
    clk            => CLK1MHZ,
    en_store       => EN_STORE_DATA,
    en_in          => EN_DATA,
    data_in        => DATA_BIT,
    en_addr_search => EN_ADD_SRCH,
    led_debug_out  => LED_0_DEBUG,
    reg_rdy        => TEMP_RDY,
    en_addr_out    => ADDR_TRANS_EN,
    addr_sel_in    => ADDR_SEL,
    addr_sel_vis   => ADDR_VIS_SEL,
    addr_in        => ADDR_DS_STORE,
    addr_out       => ADDR_STORE_DS,
    temp_out       => TEMP_DATA
    ); 

U4: vga port map(
    clk            => MHZ100,
    sresetn        => RES_IN,
    vgaRed         => vgaRed,
    vgaGreen       => vgaGreen,
    vgaBlue        => vgaBlue,
    Hsync          => Hsync,
    Vsync          => Vsync,
    tempval_ready  => TEMP_RDY,
    sensor_address => ADDR_VIS_SEL,
    tempval_in     => TEMP_DATA
    );

U5: seven_segment_display port map(
    clk                => CLK1MHZ,
    tempval_ready      => TEMP_RDY,
    sresetn            => RES_IN,
    tempval_in         => TEMP_DATA,
    sensor_address     => ADDR_VIS_SEL,
    sensor_select      => SWITCHES,
    seven_segments_out => OUTPUT_7SEG,
    decimal_point_out  => EN_DEC_POINT,
    digit_enable_out   => EN_7SEG_DIG
    );

end Mapping;