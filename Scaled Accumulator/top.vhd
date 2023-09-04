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

entity top is
    Generic ( 
        constant G_DATA_WIDTH : positive := 8;
        constant G_ES : integer :=2); 
    Port (
        clk : in std_logic;
        acc_op : in std_logic;
        sub : in std_logic; -- 0=> addition; 1=> subtraction
        pa : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        pb : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        pc : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        pr : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        nar : out std_logic;
        zero : out std_logic );
end top;

architecture Behavioral of top is
    
    constant G_MAX_EXP_SIZE : positive := ceil_log2(G_DATA_WIDTH);
    
	signal d_acc_op, d_sub : std_logic;
	signal d_pa, d_pb, d_pc : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    -- Outputs (registered) of decode stages
    signal d_pa_sf, d_pb_sf, d_pc_sf : std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    signal d_pa_frac, d_pb_frac, d_pc_frac : std_logic_vector(G_DATA_WIDTH-G_ES-3 downto 0);
    signal d_pa_sig, d_pb_sig, d_pc_sig : std_logic;
    signal d_pa_nar, d_pb_nar, d_pc_nar : std_logic;
    signal d_pa_zero, d_pb_zero, d_pc_zero : std_logic;

    -- Outputs (registered) of multiply stage
    signal m_s_sig, m_s_nar, m_s_zero : std_logic;
    signal m_s_sf  : std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    signal m_s_frac : std_logic_vector(2*(G_DATA_WIDTH-G_ES-2)-1 downto 0);
    signal m_pc_frac : std_logic_vector(G_DATA_WIDTH-G_ES-3 downto 0);
    signal m_pc_sig : std_logic;
    signal m_pc_nar : std_logic;
    signal m_pc_zero : std_logic;
    signal m_pc_sf  : std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);           
    
    -- Outputs (registered - twice) of add/accumulate stage
    signal a_s_sig : std_logic;
    signal a_s_sf  : std_logic_vector(G_ES+G_MAX_EXP_SIZE+1 downto 0);
    signal a_s_frac : std_logic_vector(G_DATA_WIDTH-G_ES-1 downto 0);
    signal a_s_nar, a_s_zero : std_logic;
    signal a_s_sticky : std_logic;
    signal a_s_ovf_reg : std_logic;
    
    
    signal m_acc_op, a_acc_op : std_logic;
    signal m_sub, a_sub : std_logic;
    
begin

------------------------------------------------------
-- Input Register
------------------------------------------------------
    inpput_reg: process(clk)
    begin
        if rising_edge(clk) then
            d_acc_op <= acc_op;
            d_sub <= sub;
			d_pa <= pa;
            d_pb <= pb;
            d_pc <= pc;
        end if;
    end process;
 


------------------------------------------------------
-- Signal Propagation (acc, sub)
------------------------------------------------------
    progagate: process(clk)
    begin
        if rising_edge(clk) then
            m_acc_op <= d_acc_op;
            a_acc_op <= m_acc_op;
            
            m_sub <= d_sub;
            a_sub <= m_sub;
        end if;
    end process;


------------------------------------------------------
-- Decode Stages for Operands A,B,C
------------------------------------------------------
        
    decode_A : posit_decode
        generic map ( G_DATA_WIDTH => G_DATA_WIDTH, G_ES => G_ES, G_MAX_EXP_SIZE => G_MAX_EXP_SIZE)
        port map(
            clk => clk,
            pos => d_pa,
            sig => d_pa_sig,
            sf => d_pa_sf,
            frac => d_pa_frac,
            nar => d_pa_nar,
            zero => d_pa_zero
        );
            
    decode_B : posit_decode
        generic map ( G_DATA_WIDTH => G_DATA_WIDTH, G_ES => G_ES, G_MAX_EXP_SIZE => G_MAX_EXP_SIZE)
        port map(
            clk => clk,
            pos => d_pb,
            sig => d_pb_sig,
            sf => d_pb_sf,
            frac => d_pb_frac,
            nar => d_pb_nar,
            zero => d_pb_zero
        );
            
    decode_C : posit_decode
        generic map ( G_DATA_WIDTH => G_DATA_WIDTH, G_ES => G_ES, G_MAX_EXP_SIZE => G_MAX_EXP_SIZE)
        port map(
            clk => clk,
            pos => d_pc,
            sig => d_pc_sig,
            sf => d_pc_sf,
            frac => d_pc_frac,
            nar => d_pc_nar,
            zero => d_pc_zero
        );        

------------------------------------------------------
-- Multiply Stage => S = A * B
------------------------------------------------------

    multiply : posit_mult
        generic map ( G_DATA_WIDTH => G_DATA_WIDTH, G_ES => G_ES, G_MAX_EXP_SIZE => G_MAX_EXP_SIZE)
        port map(
            clk => clk,
            a_sig => d_pa_sig,
            a_sf => d_pa_sf,
            a_frac => d_pa_frac,
            a_zero => d_pa_zero,
            a_nar => d_pa_nar,
            
            b_sig => d_pb_sig,
            b_sf => d_pb_sf,
            b_frac => d_pb_frac,
            b_zero => d_pb_zero,
            b_nar => d_pb_nar,
            
            s_sig => m_s_sig,
            s_sf => m_s_sf,
            s_frac => m_s_frac,
            s_zero => m_s_zero,
            s_nar => m_s_nar
        );        

    mult_seq: process(clk)
    begin
        if rising_edge(clk) then
            m_pc_frac <= d_pc_frac;
            m_pc_sig <= d_pc_sig;
            m_pc_nar <= d_pc_nar;
            m_pc_zero <= d_pc_zero;
            m_pc_sf <= d_pc_sf;
        end if;
    end process;

------------------------------------------------------
-- Add Stage => S = M + C
------------------------------------------------------
    add : posit_quire_add
        generic map ( G_DATA_WIDTH => G_DATA_WIDTH, G_ES => G_ES, G_MAX_EXP_SIZE => G_MAX_EXP_SIZE)
        port map(
            clk => clk,
            acc => a_acc_op,
            sub => a_sub,
            
            m_sig => m_s_sig,
            m_sf => m_s_sf,
            m_frac => m_s_frac,
            m_nar => m_s_nar,
            m_zero => m_s_zero,
            
            c_sig => m_pc_sig,
            c_sf => m_pc_sf,
            c_frac => m_pc_frac,
            c_nar => m_pc_nar,
            c_zero => m_pc_zero,
            
            s_sig => a_s_sig,
            s_sf => a_s_sf,
            s_frac => a_s_frac,
            s_nar => a_s_nar,
            s_zero => a_s_zero,
            s_sticky => a_s_sticky
            --s_ovf_reg => a_s_ovf_reg
        );   

------------------------------------------------------
-- Encode (registered) stage
------------------------------------------------------
    encode : posit_encode
    generic map ( G_DATA_WIDTH => G_DATA_WIDTH, G_ES => G_ES, G_MAX_EXP_SIZE => G_MAX_EXP_SIZE)
    port map(
        clk => clk,
        nar => a_s_nar,
        zero => a_s_zero,
        sig => a_s_sig,
        sf_quire => a_s_sf,
        frac => a_s_frac,
        sticky => a_s_sticky,
        --ovf_reg => a_s_ovf_reg,
        s_nar => nar,
        s_zero => zero,
        s_pos => pr
    );        

end Behavioral;
