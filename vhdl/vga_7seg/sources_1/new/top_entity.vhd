library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;

entity top_entity is
    Port ( clk,
        tempval_ready, 
        sresetn : in std_logic;
        sensor_address: in std_logic_vector(1 downto 0);
        sensor_select: in std_logic_vector(1 downto 0);
        tempval_in : in std_logic_vector(11 downto 0); --temperature input
        seven_segments_out : out  std_logic_vector(6 downto 0); --7-segments for display, 0=on, 1=off
        decimal_point_out : out std_logic; --decimal point for display, 0=on, 1=off
        digit_enable_out: out  std_logic_vector(3 downto 0); --anodes for activating each digit. 0=on, 1=off
        vgaRed : out std_logic_vector(3 downto 0);
        vgaGreen : out std_logic_vector(3 downto 0);
        vgaBlue : out std_logic_vector(3 downto 0);
        Hsync : out std_logic;
        Vsync : out std_logic
        );
end top_entity;

architecture rtl of top_entity is

component clk_div is
    Port ( 
        clk_in : in std_logic;
        clk_out : out std_logic
    );
end component;

component seven_segment_display is
port(
    clk                : in  std_logic;
    tempval_ready      : in  std_logic; 
    sresetn            : in  std_logic;
    sensor_address     : in std_logic_vector(1 downto 0); --id of the sensor which sends new data
    sensor_select      : in std_logic_vector(1 downto 0); --id of sensor data to be displayed
    tempval_in         : in  std_logic_vector(11 downto 0);
    seven_segments_out : out std_logic_vector(6 downto 0);
    decimal_point_out  : out std_logic;
    digit_enable_out   : out std_logic_vector(3 downto 0)
    );
end component;

component vga is
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

    );
end component;

signal clk1mhz       : STD_LOGIC;

begin

U1: clk_div port map(
    clk_in => clk,
    clk_out => clk1mhz
    );

U2: seven_segment_display port map(
    clk                => clk1mhz,
    tempval_ready      => tempval_ready,
    sresetn            => sresetn,
    sensor_address     => sensor_address,
    sensor_select      => sensor_select,
    tempval_in         => tempval_in,
    seven_segments_out => seven_segments_out,
    decimal_point_out  => decimal_point_out,
    digit_enable_out   => digit_enable_out
    );
U3: vga port map(
    vgaRed          => vgaRed,
    vgaGreen        => vgaGreen,
    vgaBlue         => vgaBlue,
    Hsync           => Hsync,
    Vsync           => Vsync,
    clk             => clk,
    sresetn         => sresetn,
    tempval_ready   => tempval_ready,
    sensor_address  => sensor_address,
    tempval_in      => tempval_in
    );
end architecture;
