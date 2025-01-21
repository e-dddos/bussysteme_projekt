----------------------------------------------------------------------------------
-- University: HAW Hamburg
-- Engineer(s): Valentin Kniesel, Eduard Lomtadze, Uwe Scharnweber : Students
-- 
-- Create Date: 2025
-- Design Name: Dynamic 1-Wire Multi DS18B20 Processing (With simple VGA output)
-- Module Name: CLK Division - Clock devider, which changes the Basys 3 internal
-- 				100 MHz to 1 MHz. This clock is used for all modules.
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity clk_division is
    Port ( 
		clk_in  : in  STD_LOGIC; -- 100 MHz
        clk_out : out STD_LOGIC	 -- 1 MHz
		);
end clk_division;
architecture CLK_div of clk_division is

-- counter for clock division
SIGNAL count: INTEGER RANGE 0 to 99; -- 100 MHz / 100 = 1 MHz

begin
process (clk_in)
begin
	if (rising_edge(clk_in)) then
		count <= count + 1;
		if (count = 99) then
			count <= 0;
			clk_out <= '1';
		else
			clk_out <= '0';
		end if;
	end if;
end process;

end CLK_div;
