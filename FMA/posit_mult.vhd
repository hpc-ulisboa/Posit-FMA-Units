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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

use work.posit_Pkg.all;

entity posit_mult is
    Generic ( 
        constant G_DATA_WIDTH : positive := 32;
        constant G_ES : integer :=2;
        constant G_MAX_EXP_SIZE : positive :=5); --ceil_log2(G_DATA_WIDTH)
    Port ( clk : in std_logic;
        a_sig : in std_logic;
        a_sf : in std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
        a_frac : in std_logic_vector(G_DATA_WIDTH-G_ES-3 downto 0);
        a_zero : in std_logic;
        a_nar : in std_logic;
        
        b_sig : in std_logic;
        b_sf: in std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
        b_frac : in std_logic_vector(G_DATA_WIDTH-G_ES-3 downto 0);
        b_zero : in std_logic;
        b_nar : in std_logic;
        
        s_sig : out std_logic;
        s_sf  : out std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
        s_frac : out std_logic_vector(2*(G_DATA_WIDTH-G_ES-2)-1 downto 0);
        s_zero : out std_logic;
        s_nar : out std_logic
        
     );
end posit_mult;

architecture Behavioral of posit_mult is
    
    signal sf_add : std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    signal mult_frac : std_logic_vector(2*(G_DATA_WIDTH-G_ES-2)-1 downto 0);
    signal ovf_mult, r_zero, r_nar : std_logic;
    
    signal r_sig : std_logic;
    signal r_sf  : std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    signal r_frac : std_logic_vector(2*(G_DATA_WIDTH-G_ES-2)-1 downto 0);
begin
    
    r_zero <= a_zero or b_zero;
    r_nar <= a_nar or b_nar;
    
    -- Sign calculation
    r_sig <= a_sig xor b_sig;
   
    -- Multiply fractions
    mult_frac <=  std_logic_vector(unsigned(a_frac) * unsigned(b_frac));
    ovf_mult <= mult_frac(2*(G_DATA_WIDTH-G_ES-2)-1);
    
    -- Adjusting for overflow
    r_frac <= mult_frac(2*(G_DATA_WIDTH-G_ES-2)-2 downto 0) & '0' when ovf_mult = '0' else
              mult_frac(2*(G_DATA_WIDTH-G_ES-2)-1 downto 0);
  
  
    -- Exponent addition w/ overflow adjustment
    sf_add <= std_logic_vector(unsigned(a_sf) + unsigned(b_sf)+ ("" & ovf_mult));
    
    -- Outputs 
    r_sf <= sf_add;
        
    
    seq: process(clk)      
    begin
        if rising_edge(clk) then
            s_sig <= r_sig;
            s_sf <= r_sf;
            s_frac <= r_frac;
            s_nar <= r_nar;
            s_zero <= r_zero;
        end if;
    end process;
  
    
end Behavioral;
