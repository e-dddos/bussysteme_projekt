library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity clk_division is
    Port ( clk_in : in STD_LOGIC;
           clk_out : out STD_LOGIC);
end clk_division;

architecture CLK_div of clk_division is

-- counter for clock division
SIGNAL count: INTEGER RANGE 0 to 99; 

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
