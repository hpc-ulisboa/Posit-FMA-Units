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

entity posit_quire_add is
    Generic ( 
        constant G_DATA_WIDTH : positive := 32;
        constant G_ES : integer :=2;
        constant G_MAX_EXP_SIZE : positive :=5); --ceil_log2(G_DATA_WIDTH)
    Port ( clk : in std_logic;
           acc : in std_logic;
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
           s_zero : out std_logic;
           s_sticky : out std_logic
           --s_ovf_reg: out std_logic
     );
end posit_quire_add;

architecture Behavioral of posit_quire_add is
    
  
    constant C_CG : integer := 7; -- reduced quire
    constant C_NQ : integer := 2*(G_DATA_WIDTH-2); 
    constant C_QS : integer := 4*(G_DATA_WIDTH-2)+C_CG+1;
    constant C_Q_SIZE : integer := ceil_log2(C_QS);
    constant C_SF_OFFSET : std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0) :=  std_logic_vector(to_unsigned(C_NQ, G_ES+G_MAX_EXP_SIZE+2));
    constant C_CLZ_OFFSET : integer := C_CG +C_NQ;
    
    constant INT_SAT : std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0) :=  std_logic_vector(to_unsigned(C_NQ, G_ES+G_MAX_EXP_SIZE+2));
    constant INT_SAT_QS : std_logic_vector(C_Q_SIZE-1 downto 0) :=  std_logic_vector(to_unsigned(C_NQ, C_Q_SIZE));
    
    --quire conversion
    --m
    signal m_r_sig : std_logic;
    signal ext_mf : std_logic_vector(2*(G_DATA_WIDTH-G_ES-2)-1 downto 0);
    signal m_fixed_frac : std_logic_vector(C_QS-1 downto 0);
    --signal m_sf_sat, m_sf_fixed: std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    --signal mult_sf_ovf: std_logic;
    --signal mult_fixed_shamt: std_logic_vector(C_Q_SIZE-1 downto 0);
    --c
    signal ext_cf : std_logic_vector(G_DATA_WIDTH-G_ES-3 downto 0);
    signal c_fixed_frac : std_logic_vector(C_QS-1 downto 0);
    --signal c_sf_sat, c_sf_fixed: std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    --signal c_sf_ovf: std_logic; 
    --signal add_fixed_shamt : std_logic_vector(C_Q_SIZE-1 downto 0);
    
    -- align and add
    signal c_quire : std_logic_vector(C_QS-1 downto 0);
    signal add_sf: std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    signal add_zero, add_nar : std_logic;
    signal xor_sf, align_sel: std_logic;
    signal fixed_quire, align_quire, shift_quire: std_logic_vector(C_QS-1 downto 0);
    signal diff_sf, diff_sf_inv: std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    signal shamt : std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    signal shamt_sat: std_logic_vector(C_Q_SIZE-1 downto 0);
    signal add_quire : std_logic_vector(C_QS-1 downto 0);
    signal shift_carry: std_logic;
    signal s_quire_sf, s_quire_sf_tmp: std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    signal s_quire_tmp, s_quire: std_logic_vector(C_QS-1 downto 0);
    signal s_quire_nar: std_logic;
    
    --normalization
    signal r_quire: std_logic_vector(C_QS-1 downto 0);
    signal r_quire_sf: std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    signal r_quire_nar: std_logic;
    
    signal r_quire_zero: std_logic;
    signal r_sig: std_logic;
    signal ext_q : std_logic_vector(C_QS-1 downto 0);
    signal comp_quire: std_logic_vector(C_QS-1 downto 0);
    signal comp_quire_ext: std_logic_vector(2**ceil_log2(C_QS)-1 downto 0);    
    signal zc: std_logic_vector(C_Q_SIZE-1 downto 0);
    
    signal ss_sig: std_logic;
    signal ss_comp_quire : std_logic_vector(C_QS-1 downto 0);
    signal ss_quire_sf : std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    signal ss_quire_nar, ss_quire_zero : std_logic;
    signal ss_zc : std_logic_vector(C_Q_SIZE-1 downto 0);
    
    signal frac_quire : std_logic_vector(C_QS-1 downto 0);
    signal r_sticky, r_ovf_reg : std_logic;
    signal r_sf_ext : std_logic_vector(C_Q_SIZE downto 0);
    signal r_sf_offset  : std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    signal r_sf  : std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    signal r_frac : std_logic_vector(G_DATA_WIDTH-G_ES-1 downto 0);
begin
    
    -- Convert fractions to quire(fixed-point) 2's complement
    -- m
    m_r_sig <= (m_sig xor sub) and not m_zero;
    ext_mf <= (others=> m_r_sig);
    m_fixed_frac(C_QS-1 downto 2*C_NQ+1) <= (others => m_r_sig);
    m_fixed_frac(2*C_NQ downto 2*C_NQ-2*(G_DATA_WIDTH-G_ES-2)+1) <= std_logic_vector(unsigned(m_frac xor ext_mf) +  ("" & m_r_sig));
    m_fixed_frac(2*C_NQ-2*(G_DATA_WIDTH-G_ES-2) downto 0) <= (others => '0');
    
--    m_sf_sat <= std_logic_vector(unsigned(m_sf) - unsigned(INT_SAT));
    
--    mult_sf_ovf <= m_sf_sat(G_ES+G_MAX_EXP_SIZE+1) nor m_sf(G_ES+G_MAX_EXP_SIZE+1);
    
--    m_sf_fixed <= m_sf when m_sf(G_ES+G_MAX_EXP_SIZE+1)='1' else
--                  m_sf_sat when mult_sf_ovf='1' else
--                  (others => '0'); 
                  
--    mult_fixed_shamt <= INT_SAT_QS when m_sf(G_ES+G_MAX_EXP_SIZE+1)='1' else
--                        (others => '0') when mult_sf_ovf='1' else
--                        --std_logic_vector(unsigned(m_sf_sat(C_Q_SIZE-1 downto 0) xor (C_Q_SIZE-1 downto 0 => '1')) + ("" & '1'));
--                        std_logic_vector(unsigned(INT_SAT_QS)- unsigned(m_sf(C_Q_SIZE-1 downto 0)));
    -- c
    ext_cf <= (others=> c_sig);
    c_fixed_frac(C_QS-1 downto 2*C_NQ+1) <= (others => c_sig);
    c_fixed_frac(2*C_NQ downto 2*C_NQ-(G_DATA_WIDTH-G_ES-3)) <= std_logic_vector(unsigned(c_frac xor ext_cf) +  ("" & c_sig));
    c_fixed_frac(2*C_NQ-(G_DATA_WIDTH-G_ES-3)-1 downto 0) <= (others => '0');
    
    
--    c_sf_sat <= std_logic_vector(unsigned(c_sf) - unsigned(INT_SAT));

--    c_sf_ovf <= c_sf_sat(G_ES+G_MAX_EXP_SIZE+1) nor c_sf(G_ES+G_MAX_EXP_SIZE+1);

                        
--    c_sf_fixed <= c_sf when c_sf(G_ES+G_MAX_EXP_SIZE+1)='1' else
--                  c_sf_sat when c_sf_ovf='1' else
--                  (others=> '0');                 
                       
--    add_fixed_shamt <= (others => '0') when acc = '1' else
--                       INT_SAT_QS when c_sf(G_ES+G_MAX_EXP_SIZE+1)='1' else
--                       (others => '0') when c_sf_ovf='1' else
--                       --std_logic_vector(unsigned(c_sf_sat(C_Q_SIZE-1 downto 0) xor (C_Q_SIZE-1 downto 0 => '1')) + ("" & '1'));
--					   std_logic_vector(unsigned(INT_SAT_QS)- unsigned(c_sf(C_Q_SIZE-1 downto 0)));
						
						
    -- select from register or operand C
    c_quire <= r_quire when acc = '1' else
               c_fixed_frac;
                 
    add_sf <= r_quire_sf when acc = '1' else
              c_sf;
    
    add_zero <= r_quire_zero when acc = '1' else
                c_zero;
    
    add_nar <= r_quire_nar when acc = '1' else
               c_nar;            
                
    -- Accumulation / Addition
    -- align exponents
    xor_sf <= m_sf(G_ES+G_MAX_EXP_SIZE+1) xor add_sf(G_ES+G_MAX_EXP_SIZE+1);
    align_sel <= '0' when (xor_sf = '1' and m_sf(G_ES+G_MAX_EXP_SIZE+1) = '0' and m_zero='0') 
                           or (xor_sf = '0' and not (m_sf < add_sf) and m_zero='0') 
                           or (add_zero='1' and m_sf(G_ES+G_MAX_EXP_SIZE+1)='1') else
                 '1';
    
    fixed_quire <= m_fixed_frac when align_sel = '0' else
                   add_quire;
    
    align_quire <= m_fixed_frac when align_sel = '1' else
                   add_quire; 
    
    
    diff_sf <= std_logic_vector(unsigned(m_sf) - unsigned(add_sf));
    diff_sf_inv <= std_logic_vector(unsigned(add_sf) - unsigned(m_sf));
    
    shamt <= diff_sf when align_sel = '0' else
             diff_sf_inv;
            
    shamt_sat <= shamt(C_Q_SIZE-1 downto 0) when is_zero(shamt(G_ES+G_MAX_EXP_SIZE+1 downto C_Q_SIZE)) = '1' else
                 (others => '1');
                   
    align_m : barrel_sre generic map ( G_DATA_WIDTH => C_QS, G_SHIFT_SIZE => C_Q_SIZE)
              port map( A => align_quire, shamt => shamt_sat, S => shift_quire);
                   
    s_quire_sf_tmp <= m_sf when align_sel='0' else
                      add_sf;

    
    -- add quires
    s_quire_tmp <= std_logic_vector(unsigned(fixed_quire) + unsigned(shift_quire));
    
    shift_carry <= s_quire_tmp (C_QS-2) xor s_quire_tmp (C_QS-1);
    s_quire <= s_quire_tmp when shift_carry='1' else
               s_quire_tmp (C_QS-1) & s_quire_tmp(C_QS-1 downto 1);
    
    s_quire_sf <= std_logic_vector(unsigned(s_quire_sf_tmp) + ("" & shift_carry)); 
    s_quire_nar <= add_nar or m_nar;
    
    seq: process(clk)
    begin
        if rising_edge(clk) then
           r_quire <= s_quire;
           r_quire_sf <= s_quire_sf;
           r_quire_nar <= s_quire_nar;
        end if;
    end process;
    
    r_quire_zero <= is_zero(r_quire);
    
    
    r_sig <= r_quire(C_QS-1);
    
    -- from 2's complement
    ext_q <= (others=> r_quire(C_QS-1));
    comp_quire <= std_logic_vector(unsigned(r_quire xor ext_q) + ("" & r_quire(C_QS-1)));
    
    comp_quire_ext <= comp_quire(C_QS-1 downto 1) & ((2**ceil_log2(C_QS)-C_QS) downto 0 => comp_quire(0)); -- Extend to base 2 number
    leading_zeroes: clz generic map ( G_DATA_WIDTH => 2**ceil_log2(C_QS), G_COUNT_WIDTH => C_Q_SIZE)
                    port map( A => comp_quire_ext, C => zc, V => open);
    
    
--   split_seq: process(clk)
--   begin
--       if rising_edge(clk) then
            ss_sig <= r_sig;
            ss_comp_quire <= comp_quire;
            ss_quire_sf <= r_quire_sf;
            ss_quire_nar <= r_quire_nar;
            ss_quire_zero <= r_quire_zero;
            ss_zc <= zc;
--       end if;
--   end process;
    
    shift_fraction: barrel_sl generic map ( G_DATA_WIDTH => C_QS, G_SHIFT_SIZE => C_Q_SIZE)
                 port map( A => ss_comp_quire, shamt => ss_zc, S => frac_quire);
    
    r_frac <= frac_quire(C_QS-1 downto C_QS-(G_DATA_WIDTH-G_ES));
    
    r_sticky <= is_zero(frac_quire(C_QS-(G_DATA_WIDTH-G_ES)-1 downto C_QS-2*(G_DATA_WIDTH-G_ES))); -- Can possibly be reduced
    
    r_sf_ext <= std_logic_vector(C_CLZ_OFFSET - unsigned('0' & ss_zc)); -- align with zero count
    
    --r_ovf_reg <= is_not_zero(r_sf_ext(C_Q_SIZE-1 downto G_ES+G_MAX_EXP_SIZE+1)) and not r_sf_ext(C_Q_SIZE);
    --r_sf_offset <= r_sf_ext(C_Q_SIZE) & r_sf_ext(G_ES+G_MAX_EXP_SIZE downto 0);
    
    r_sf <= std_logic_vector(unsigned(ss_quire_sf) + unsigned(r_sf_ext));
    
    out_seq: process(clk)
    begin
        if rising_edge(clk) then
           s_frac <= r_frac;
           s_sf <= r_sf;
           s_sig <= ss_sig;
           s_nar <= ss_quire_nar;
           s_zero <= ss_quire_zero;
           s_sticky <= r_sticky;
           --s_ovf_reg <= r_ovf_reg;
        end if;
    end process;
    
end Behavioral;
