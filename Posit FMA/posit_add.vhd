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

entity posit_add is
    Generic ( 
        constant G_DATA_WIDTH : positive := 32;
        constant G_ES : integer :=2;
        constant G_MAX_EXP_SIZE : positive :=5); --ceil_log2(G_DATA_WIDTH)
    Port ( clk : in std_logic;
           sub : in std_logic;
            
           m_sig : in std_logic;
           m_sf  : in std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
           m_frac : in std_logic_vector(2*(G_DATA_WIDTH-G_ES-2)-1 downto 0);
           m_nar : in std_logic;
           m_zero : in std_logic;
            
           c_sig : in std_logic;
           c_sf  : in std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
           c_frac : in std_logic_vector(G_DATA_WIDTH-G_ES-3 downto 0);
           c_nar : in std_logic;
           c_zero : in std_logic;
            
           s_sig : out std_logic;
           s_sf  : out std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
           s_frac : out std_logic_vector(G_DATA_WIDTH-G_ES-1 downto 0);
           s_nar : out std_logic;
           s_sticky : out std_logic;
           s_ovf_reg: out std_logic
     );
end posit_add;

architecture Behavioral of posit_add is
    
    signal xor_sf, align_sel : std_logic;
    signal sf_diff, sf_diff_inv, align_shamt: std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    signal sat_shamt: std_logic_vector(ceil_log2(2*(G_DATA_WIDTH-G_ES-2))-1 downto 0);
    
    signal fixed_frac, align_frac, ext_sub, s_frac_add, s_frac_add_tmp,inv: std_logic_vector(2*(G_DATA_WIDTH-G_ES-2)-1 downto 0);
    signal shift_frac: std_logic_vector(4*(G_DATA_WIDTH-G_ES-2)-1 downto 0);
    signal s_sf_add: std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    signal s_sign_add, op, s_nar_add, r_nar_add, r_sign_add: std_logic;
    
    
    signal r_frac_add: std_logic_vector(2*(G_DATA_WIDTH-G_ES-2)-1 downto 0);
    signal r_sf_add:std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    
    signal frac_add_ext: std_logic_vector(2**ceil_log2(2*(G_DATA_WIDTH-G_ES-2))-1 downto 0);
    signal zc: std_logic_vector(ceil_log2(2*(G_DATA_WIDTH-G_ES-2))-1 downto 0);
    
    signal r_frac_tmp: std_logic_vector(2*(G_DATA_WIDTH-G_ES-2)-1 downto 0);
    
    
    signal r_sig, ss_sig, r_sticky : std_logic;
    signal r_sf  : std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    signal r_frac : std_logic_vector(G_DATA_WIDTH-G_ES-1 downto 0);
begin
        

    -- Accumulation / Addition
    -- align exponents
    xor_sf <= m_sf(G_ES+G_MAX_EXP_SIZE+1) xor c_sf(G_ES+G_MAX_EXP_SIZE+1);
    align_sel <= '0' when (xor_sf = '1' and m_sf(G_ES+G_MAX_EXP_SIZE+1) = '0' and m_zero='0') 
                           or (xor_sf = '0' and not (m_sf < c_sf) and m_zero='0') 
                           or (c_zero='1' and m_sf(G_ES+G_MAX_EXP_SIZE+1)='1') else
                 '1';
                 
    sf_diff <= std_logic_vector(unsigned(m_sf) - unsigned(c_sf)); 
    sf_diff_inv <= std_logic_vector(unsigned(c_sf) - unsigned(m_sf)); 
    
        
   
    align_shamt <= sf_diff when align_sel = '0' else
                   sf_diff_inv;
                    
    sat_shamt <= align_shamt(ceil_log2(2*(G_DATA_WIDTH-G_ES-2))-1 downto 0) when is_zero(align_shamt(G_ES+G_MAX_EXP_SIZE+1 downto ceil_log2(2*(G_DATA_WIDTH-G_ES-2)))) = '1' else
                 (others => '1');
    
    fixed_frac <= m_frac when align_sel = '0' else
                  c_frac & (G_DATA_WIDTH-G_ES-3 downto 0 => '0');
    
    align_frac <= c_frac & (G_DATA_WIDTH-G_ES-3 downto 0 => '0') when align_sel = '1' else
                  m_frac; 
                   
    align_shifter : barrel_sr generic map ( G_DATA_WIDTH => 2*(G_DATA_WIDTH-G_ES-2), G_SHIFT_SIZE => ceil_log2(2*(G_DATA_WIDTH-G_ES-2)))
                   port map( A => align_frac, shamt => sat_shamt, S => shift_frac);

                
    s_sf_add <= m_sf when align_sel = '0' else
                c_sf;
                
    s_sign_add <= m_sig when align_sel = '0' else
                  c_sig xor sub;
    
    op <= m_sig xor c_sig xor sub;
    
    ext_sub <= (2*(G_DATA_WIDTH-G_ES-2)-1 downto 0 => sub);
    -- add quires
    s_frac_add_tmp <= std_logic_vector(unsigned(shift_frac(4*(G_DATA_WIDTH-G_ES-2)-1 downto 2*(G_DATA_WIDTH-G_ES-2)) xor ext_sub) + unsigned(fixed_frac) + ("" & sub));
    
    inv <= (2*(G_DATA_WIDTH-G_ES-2)-1 downto 0 => s_frac_add_tmp(2*(G_DATA_WIDTH-G_ES-2)-2) and not s_frac_add_tmp(2*(G_DATA_WIDTH-G_ES-2)-1) and op);
    s_frac_add <= std_logic_vector(unsigned(s_frac_add_tmp xor inv) + ("" & s_frac_add_tmp(2*(G_DATA_WIDTH-G_ES-2)-1)));
    
    s_nar_add <= c_nar or m_nar;
    
    seq: process(clk)
    begin
        if rising_edge(clk) then
           r_frac_add <= s_frac_add;
           r_sf_add <= s_sf_add;
           r_nar_add <= s_nar_add;
           r_sign_add <= s_sign_add;
        end if;
    end process;
   

    frac_add_ext <= r_frac_add(2*(G_DATA_WIDTH-G_ES-2)-1 downto 1) & ((2**ceil_log2(2*(G_DATA_WIDTH-G_ES-2))-2*(G_DATA_WIDTH-G_ES-2)) downto 0 => r_frac_add(0)); -- Extend to base 2 number
    leading_zeroes: clz generic map ( G_DATA_WIDTH => 2**ceil_log2(2*(G_DATA_WIDTH-G_ES-2)), G_COUNT_WIDTH => ceil_log2(2*(G_DATA_WIDTH-G_ES-2)))
                    port map( A => frac_add_ext, C => zc, V => open);
    
    
    shift_fraction: barrel_sl generic map ( G_DATA_WIDTH => 2*(G_DATA_WIDTH-G_ES-2), G_SHIFT_SIZE => ceil_log2(2*(G_DATA_WIDTH-G_ES-2)))
                 port map( A => r_frac_add, shamt => zc, S => r_frac_tmp);
    
    r_frac <= r_frac_tmp(2*(G_DATA_WIDTH-G_ES-2)-1 downto 2*(G_DATA_WIDTH-G_ES-2)-(G_DATA_WIDTH-G_ES));
    
    r_sticky <= is_zero(r_frac_tmp(2*(G_DATA_WIDTH-G_ES-2)-(G_DATA_WIDTH-G_ES)-1 downto 0));
    
    r_sf <= std_logic_vector(unsigned(r_sf_add) - unsigned(zc));
    
    out_seq: process(clk)
    begin
        if rising_edge(clk) then
           s_frac <= r_frac;
           s_sf <= r_sf;
           s_sig <= r_sign_add;
           s_nar <= r_nar_add;
           s_sticky <= r_sticky;
        end if;
    end process;
    
end Behavioral;
