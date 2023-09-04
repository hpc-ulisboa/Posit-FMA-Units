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

use work.posit_Pkg.ALL;

entity posit_encode is
    Generic ( 
        constant G_DATA_WIDTH : positive := 32;
        constant G_ES : integer :=2;
        constant G_MAX_EXP_SIZE : positive :=5); --ceil_log2(G_DATA_WIDTH)
    Port ( clk : in std_logic;
        nar : in std_logic;
        sig : in std_logic;
        sf_quire : in std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
        frac : in std_logic_vector(G_DATA_WIDTH-G_ES-1 downto 0);
        sticky : in std_logic;
        ovf_reg : in std_logic;
        s_nar : out std_logic;
        s_zero : out std_logic;
        s_pos : out std_logic_vector(G_DATA_WIDTH-1 downto 0) );
end posit_encode;

architecture Behavioral of posit_encode is
    
    constant MAX_REG : std_logic_vector(G_MAX_EXP_SIZE-1 downto 0) :=  std_logic_vector(to_unsigned(G_DATA_WIDTH-2, G_MAX_EXP_SIZE));
    
    signal reg, abs_reg, ext_cr : std_logic_vector(G_MAX_EXP_SIZE+1 downto 0);
    
    signal k, offset : std_logic_vector(G_MAX_EXP_SIZE-1 downto 0);
    signal pre_ref, unrounded: std_logic_vector(2*G_DATA_WIDTH-1 downto 0);
    
    signal sf_sign, frac_zero, a_ovf_reg : std_logic;
    signal tmp_ref, rounded, add_round, pre_posit, ext_pos : std_logic_vector(G_DATA_WIDTH-2 downto 0);
    
    signal sticky_zero, guard, frac_lsb, round_bit : std_logic;
    
    signal r_nar :  std_logic;
    signal r_zero :  std_logic;
    signal r_pos :  std_logic_vector(G_DATA_WIDTH-1 downto 0);

begin
    
     -- Detect zero result
    frac_zero <= is_zero(frac);

    -- 2's complement regime
    sf_sign <= sf_quire(G_ES+G_MAX_EXP_SIZE+1);
    reg <= sf_quire(G_ES+G_MAX_EXP_SIZE+1 downto G_ES);
    ext_cr <= (others => sf_sign);
    abs_reg <= std_logic_vector(unsigned(reg xor ext_cr) + ("" & sf_sign));
    
    
    a_ovf_reg <= '1' when ((abs_reg > "00"&MAX_REG) or ovf_reg='1') else
                 '0'; 
    
    -- shift in regime bits
    pre_ref(2*G_DATA_WIDTH-1 downto 2*G_DATA_WIDTH-2) <= "01" when sf_sign = '1'  else
                                                         "10";
    es_0: if (G_ES = 0) generate
        pre_ref(2*G_DATA_WIDTH-3 downto 2*G_DATA_WIDTH-3-(G_DATA_WIDTH-G_ES-2)-G_ES) <= frac(G_DATA_WIDTH-G_ES-2 downto 0);
    end generate;
    es: if (G_ES > 0) generate
       pre_ref(2*G_DATA_WIDTH-3 downto 2*G_DATA_WIDTH-3-(G_DATA_WIDTH-G_ES-2)-G_ES) <= sf_quire(G_ES-1 downto 0) & frac(G_DATA_WIDTH-G_ES-2 downto 0);
    end generate;                                                     
    
    pre_ref(2*G_DATA_WIDTH-3-(G_DATA_WIDTH-G_ES-2)-G_ES-1 downto 0)<= (others => '0');
    
    offset <= MAX_REG when a_ovf_reg = '1'  else
              abs_reg(G_MAX_EXP_SIZE-1 downto 0);
             
    k <= std_logic_vector(unsigned(offset)-1) when sf_sign = '1'  else
         offset;
         
    shift_in_regime : barrel_sre generic map ( G_DATA_WIDTH => 2*G_DATA_WIDTH, G_SHIFT_SIZE => G_MAX_EXP_SIZE)
                      port map( A => pre_ref, shamt =>k , S => unrounded);
    
    -- round fraction
    tmp_ref <= unrounded(2*G_DATA_WIDTH-1 downto G_DATA_WIDTH+1);
    
    sticky_zero <= is_zero(unrounded(G_DATA_WIDTH-1 downto 0)) and sticky;
    guard <= unrounded(G_DATA_WIDTH);
    frac_lsb <= unrounded(G_DATA_WIDTH+1);
    
    round_bit <= (frac_lsb and guard and sticky_zero) or (guard and not sticky_zero);
    add_round <= (0 => round_bit and not a_ovf_reg, others => '0');
    
    rounded <= std_logic_vector(unsigned(tmp_ref) + unsigned(add_round));
    
    -- 2's complement and concat sign    
    ext_pos <= (others => sig);
    pre_posit <= std_logic_vector(unsigned(rounded xor ext_pos) +  (""&sig));
    
    
    r_pos <= (G_DATA_WIDTH-1 => '1', others => '0') when nar = '1' else
             (others => '0') when frac_zero = '1' else
             sig & pre_posit;
             
    r_zero <= frac_zero and not nar;
    r_nar <= nar;
    
    seq: process(clk)
    begin
        if rising_edge(clk) then
           s_nar <= r_nar;
           s_zero <= r_zero;
           s_pos <= r_pos;
        end if;
    end process;
    
end Behavioral;
