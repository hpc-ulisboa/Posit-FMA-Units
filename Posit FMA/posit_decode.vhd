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

entity posit_decode is
    Generic ( 
        constant G_DATA_WIDTH : positive := 32;
        constant G_ES : integer :=2;   
        constant G_MAX_EXP_SIZE : positive :=5); --ceil_log2(n)
    Port (
        clk : in std_logic;
        pos : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        sig : out std_logic;
        sf : out std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
        frac : out std_logic_vector(G_DATA_WIDTH-G_ES-3 downto 0);
        nar : out std_logic;
        zero : out std_logic );
end posit_decode;

architecture Behavioral of posit_decode is
    
    signal nzero_ref : std_logic;
    signal ref, inv, inv_pos, ext_ref : std_logic_vector(G_DATA_WIDTH-2 downto 0);
    signal ref_0, ef_0 : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal ext_sig, pad_sig : std_logic_vector(G_DATA_WIDTH-2 downto 0);
    
    signal zc: std_logic_vector(G_MAX_EXP_SIZE-1 downto 0);
    signal inv_ext: std_logic_vector(2**G_MAX_EXP_SIZE-1 downto 0);  -- Extended to the next base 2
    
    signal r_sig : std_logic;
    signal r_reg : std_logic_vector(G_MAX_EXP_SIZE downto 0);
    signal r_sf  : std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    signal r_frac : std_logic_vector(G_DATA_WIDTH-G_ES-3 downto 0);      
    signal r_nar : std_logic;
    signal r_zero : std_logic;
begin

    nzero_ref <= is_not_zero(pos(G_DATA_WIDTH-2 downto 0));
    
    --- Sign Out
    r_sig <= pos(G_DATA_WIDTH-1);
    
    ---- 2's complement if sign = 1 ----
    ext_sig <= (others=> pos(G_DATA_WIDTH-1));
    pad_sig(G_DATA_WIDTH-2 downto 1) <= (others=>'0');
    pad_sig(0) <= pos(G_DATA_WIDTH-1);
    inv_pos <= pos(G_DATA_WIDTH-2 downto 0) xor ext_sig;
    ref <= std_logic_vector(unsigned(inv_pos) +  unsigned(pad_sig));  -- 2's complemented posit
    
    ---- Regime decoding ----
    ext_ref <= (others => ref(G_DATA_WIDTH-2));                                             -- Regime bit
    inv <= ref(G_DATA_WIDTH-2 downto 0) xor ext_ref;                                        -- Invert 1's to use only LZD
    inv_ext <= inv & ((2**G_MAX_EXP_SIZE-G_DATA_WIDTH) downto 0 => ref(G_DATA_WIDTH-2));    -- Extend to base 2 number
    
    
    leading_zeroes: clz generic map ( G_DATA_WIDTH => 2**G_MAX_EXP_SIZE, G_COUNT_WIDTH => G_MAX_EXP_SIZE)
             port map( A => inv_ext, C => zc, V => open);
    
    --- Regime Out
    r_reg <= std_logic_vector(unsigned(('0' & zc)) - 1) when ref(G_DATA_WIDTH-2) = '1' else
         std_logic_vector(unsigned(not ('0' & zc)) + 1); -- 2's comp
    
    --- Exponent & Fraction decoding ----
    ref_0 <= ref & '0';
    shift_out_regime: barrel_sl generic map (G_DATA_WIDTH => G_DATA_WIDTH, G_SHIFT_SIZE => G_MAX_EXP_SIZE)
             port map( A => ref_0, shamt => zc, S => ef_0);     
    --ef <= ef_0(G_DATA_WIDTH-2 downto 0); -- shift out zc + 1
    
    es_0: if (G_ES = 0) generate
        r_sf <= r_reg(G_MAX_EXP_SIZE) & r_reg;
    end generate;
    es: if (G_ES > 0) generate
        r_sf <= r_reg(G_MAX_EXP_SIZE) & r_reg & ef_0(G_DATA_WIDTH-2 downto G_DATA_WIDTH-G_ES-1);
    end generate;
    
    r_frac <= nzero_ref & ef_0(G_DATA_WIDTH-G_ES-2 downto 2);
    
    r_nar <= pos(G_DATA_WIDTH-1) and not nzero_ref;
    r_zero <= (not pos(G_DATA_WIDTH-1)) and (not nzero_ref);
    
    seq: process(clk)
    begin
        if rising_edge(clk) then
           sig <= r_sig;
           sf <= r_sf;
           frac <= r_frac;
           nar <= r_nar;
           zero <= r_zero;
        end if;
    end process;

end Behavioral;
