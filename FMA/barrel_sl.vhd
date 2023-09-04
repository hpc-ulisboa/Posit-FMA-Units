-- Copyright 2023 IST, University of Lisbon and INESC-ID.
--
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 0.51 (the "License"); you may not use this file except in
-- compliance with the License. You may obtain a copy of the License at
-- http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
-- or agreed to in writing, software, hardware and materials distributed under
-- this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
-- CONDITIONS OF ANY KIND, either express or implied. See the License for the
-- specific language governing permissions and limitations under the License.

-- SPDX-License-Identifier: SHL-0.51
-- Author: Luís Crespo <luis.miguel.crespo@tecnico.ulisboa.pt>


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

use work.posit_Pkg.all;

entity barrel_sl is
    Generic ( 
        constant G_DATA_WIDTH : positive := 64;
        constant G_SHIFT_SIZE : positive := 6 
    );
    Port ( --clk : in std_logic;
        A : in std_logic_vector (G_DATA_WIDTH-1 downto 0);
        shamt : in std_logic_vector (G_SHIFT_SIZE-1 downto 0);
        S : out std_logic_vector (G_DATA_WIDTH-1 downto 0)
    );
end barrel_sl;

architecture Behavioral of barrel_sl is

    function shift_left(value: std_logic_vector(G_DATA_WIDTH-1 downto 0); shamt: std_logic_vector(G_SHIFT_SIZE-1 downto 0)) return std_logic_vector is
        variable result: std_logic_vector(G_DATA_WIDTH-1 downto 0);
        variable i: integer := G_SHIFT_SIZE-1;
    begin
        result := value;
        while i >= 0 loop
	       if (shamt(i) = '1') then result := result((G_DATA_WIDTH - 2**i - 1) downto 0) & ((2**i - 1) downto 0 => '0');
	       end if;
	       i:=i-1;
	    end loop;
        return result;
    end;
begin

S <= shift_left(A, shamt);

end Behavioral;

