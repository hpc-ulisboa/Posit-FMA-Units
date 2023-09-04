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
        
        s_sig : out std_logic;
        s_sf  : out std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
        s_frac : out std_logic_vector(G_DATA_WIDTH-G_ES-1 downto 0);
        s_nar : out std_logic;
        s_sticky : out std_logic;
        s_ovf_reg: out std_logic
     );
end posit_quire_add;

architecture Behavioral of posit_quire_add is
    -- OLD STANDARD
    -- Quire register w/ posit standard size := n²/2 bits
    -- Quire is:
    --  Sign [1]
    --  Carry Guard [n-1]
    --  Integer [1/4*n² - 1/2*n := nq] 
    --  Fraction [1/4*n² - 1/2*n := nq]
    
    -- NEW STANDARD
    -- Quire register w/ posit standard size := 16*n bits
    -- Quire is:
    --  Sign [1]
    --  Carry Guard [31]
    --  Integer [8*n - 16 := nq] 
    --  Fraction [8*n - 16 := nq]
    
    -- MIX - tunning the parameters (es and cg) allows changing between standards for 8, 16 and 32 bits 
    -- Quire register w/ posit standard size := 2^(es+2)*(n-2)+cg+1 bits
    -- Quire is:
    --  Sign [1]
    --  Carry Guard [cg]
    --  Integer [2^(es+1)*(n-2) := nq] 
    --  Fraction [2^(es+1)*(n-2) := nq]
    
    constant  C_CG : integer := G_DATA_WIDTH-1; -- G_DATA_WIDTH-1 for old standard
    constant  C_NQ : integer := 2**(G_ES+1)*(G_DATA_WIDTH-2);  
    constant  C_QS : integer := 2**(G_ES+2)*(G_DATA_WIDTH-2)+C_CG+1;
    constant  C_Q_SIZE : integer := ceil_log2(C_QS);
    constant  C_SF_OFFSET : std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0) :=  std_logic_vector(to_unsigned(C_NQ, G_ES+G_MAX_EXP_SIZE+2));
    constant  C_CLZ_OFFSET : integer := C_CG +C_NQ;


    signal m_r_sig : std_logic;
    signal ext_mf : std_logic_vector(2*(G_DATA_WIDTH-G_ES-2) downto 0);
    signal sm_frac, m_fixed_frac : std_logic_vector(2*C_NQ+2*(G_DATA_WIDTH-G_ES-2)-1 downto 0);
    signal m_sf_biased, c_sf_biased: std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    signal ext_cf : std_logic_vector(G_DATA_WIDTH-G_ES-2 downto 0);
    signal sc_frac, c_fixed_frac : std_logic_vector(2*C_NQ+G_DATA_WIDTH-G_ES-3 downto 0);
    
    signal r_c_quire, r_mult_quire: std_logic_vector(C_QS-1 downto 0);
    signal r_acc, r_m_nar, r_c_nar : std_logic; 
    
    signal r_quire, s_quire : std_logic_vector(C_QS downto 0);
    signal r_quire_nar, s_quire_nar, ss_quire_nar, quire_ovf, a_quire_nar : std_logic;

    signal add_quire, c_quire, mult_quire : std_logic_vector(C_QS-1 downto 0);
    signal comp_quire, ss_comp_quire, frac_quire : std_logic_vector(C_QS-1 downto 0);
    signal comp_quire_ext: std_logic_vector(2**ceil_log2(C_QS)-1 downto 0);
    
    signal add_nar : std_logic;

    signal ext_q : std_logic_vector(C_QS-1 downto 0);
    signal zc, ss_zc : std_logic_vector(C_Q_SIZE-1 downto 0);
    
    signal r_sig, ss_sig, r_sticky, r_ovf_reg : std_logic;
    signal r_sf_ext : std_logic_vector(C_Q_SIZE downto 0);
    signal r_sf : std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    signal r_frac : std_logic_vector(G_DATA_WIDTH-G_ES-1 downto 0);

begin
    
    -- Convert fractions to quire(fixed-point) 2's complement
    -- m
    m_r_sig <= (m_sig xor sub) and not m_zero;
    ext_mf <= (others=> m_r_sig);
    sm_frac <= (2*C_NQ-2 downto 0 => m_r_sig) & std_logic_vector(unsigned('0' & m_frac xor ext_mf) +  ("" & m_r_sig));
    m_sf_biased <= std_logic_vector(unsigned(m_sf) + unsigned(C_SF_OFFSET));

    mult_fixed_conv: barrel_sl generic map ( G_DATA_WIDTH => 2*C_NQ+2*(G_DATA_WIDTH-G_ES-2), G_SHIFT_SIZE => G_ES+G_MAX_EXP_SIZE+2)
                     port map( A => sm_frac, shamt => m_sf_biased, S => m_fixed_frac);
    
    
    mult_quire(C_QS-1 downto 2*C_NQ+1) <= (others => m_r_sig);
    mult_quire(2*C_NQ downto 0) <= m_fixed_frac(2*C_NQ+2*(G_DATA_WIDTH-G_ES-2)-1 downto 2*(G_DATA_WIDTH-G_ES-2)-1);
    
    -- c
    ext_cf <= (others=> c_sig);
    sc_frac <= (2*C_NQ-2 downto 0 => c_sig) & std_logic_vector(unsigned('0' & c_frac xor ext_cf) +  ("" & c_sig));
    c_sf_biased <= std_logic_vector(unsigned(c_sf) + unsigned(C_SF_OFFSET));
                               
    c_fixed_conv: barrel_sl generic map ( G_DATA_WIDTH => 2*C_NQ+G_DATA_WIDTH-G_ES-2, G_SHIFT_SIZE => G_ES+G_MAX_EXP_SIZE+2)
                  port map( A => sc_frac, shamt => c_sf_biased, S => c_fixed_frac);

    c_quire(C_QS-1 downto 2*C_NQ+1) <= (others => c_sig);
    c_quire(2*C_NQ downto 0) <= c_fixed_frac(2*C_NQ+G_DATA_WIDTH-G_ES-3 downto G_DATA_WIDTH-G_ES-3);
    
--    split_add: process(clk)
--    begin
--       if rising_edge(clk) then
            r_mult_quire <= mult_quire;
            r_c_quire <= c_quire;
            r_acc <= acc;
            r_m_nar <= m_nar;
            r_c_nar <= c_nar;
--       end if;
--    end process;
    
    -- select from register or operand C
    add_quire <= r_quire(C_QS-1 downto 0) when r_acc = '1' else
                 r_c_quire;
    
    add_nar <= a_quire_nar when r_acc = '1' else
               r_c_nar;            
                
    -- Accumulation / Addition   
    -- add quires
    s_quire <= std_logic_vector(unsigned(r_mult_quire(C_QS-1) & r_mult_quire) + unsigned(add_quire(C_QS-1) & add_quire));
    
    s_quire_nar <= add_nar or r_m_nar;
    
    seq: process(clk)
    begin
        if rising_edge(clk) then
           r_quire <= s_quire;
           r_quire_nar <= s_quire_nar;
        end if;
    end process;
    
    quire_ovf <= r_quire(C_QS-1) xor r_quire(C_QS);
    a_quire_nar <= r_quire_nar or quire_ovf;
    
    r_sig <= r_quire(C_QS-1);
    
    -- from 2's complement
    ext_q <= (others=> r_quire(C_QS-1));
    comp_quire <= std_logic_vector(unsigned(r_quire(C_QS-1 downto 0) xor ext_q) + ("" & r_quire(C_QS-1)));
    
    comp_quire_ext <= comp_quire(C_QS-1 downto 1) & ((2**ceil_log2(C_QS)-C_QS) downto 0 => comp_quire(0)); -- Extend to base 2 number
    leading_zeroes: clz generic map ( G_DATA_WIDTH => 2**ceil_log2(C_QS), G_COUNT_WIDTH => C_Q_SIZE)
                    port map( A => comp_quire_ext, C => zc, V => open);
    
    
--   split_seq: process(clk)
--   begin
--       if rising_edge(clk) then
            ss_sig <= r_sig;
            ss_comp_quire <= comp_quire;
            ss_quire_nar <= a_quire_nar;
            ss_zc <= zc;
--       end if;
--   end process;
    
    shift_fraction: barrel_sl generic map ( G_DATA_WIDTH => C_QS, G_SHIFT_SIZE => C_Q_SIZE)
                 port map( A => ss_comp_quire, shamt => ss_zc, S => frac_quire);
    

    r_frac <= frac_quire(C_QS-1 downto C_QS-(G_DATA_WIDTH-G_ES));
    
    r_sticky <= is_zero(frac_quire(C_QS-(G_DATA_WIDTH-G_ES)-1 downto C_QS-(G_DATA_WIDTH-G_ES)-C_NQ-1)); -- TODO: check if works with all cases
    
    r_sf_ext <= std_logic_vector(C_CLZ_OFFSET - unsigned('0' & ss_zc)); -- align with zero count
    
    r_ovf_reg <= is_not_zero(r_sf_ext(C_Q_SIZE-1 downto G_ES+G_MAX_EXP_SIZE+1)) and not r_sf_ext(C_Q_SIZE);
    r_sf <= r_sf_ext(C_Q_SIZE) & r_sf_ext(G_ES+G_MAX_EXP_SIZE downto 0);
   
    out_seq: process(clk)
    begin
        if rising_edge(clk) then
           s_frac <= r_frac;
           s_sf <= r_sf;
           s_sig <= ss_sig;
           s_nar <= ss_quire_nar;
           s_sticky <= r_sticky;
           s_ovf_reg <= r_ovf_reg;
        end if;
    end process;
    
end Behavioral;
