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

package posit_Pkg is

----------------------------------------------------------------------------------------------
-- STANDARD COMPONENTS IN POSIT_PKG
----------------------------------------------------------------------------------------------
    component clz is
        Generic ( 
            constant G_DATA_WIDTH : positive := 64;
            constant G_COUNT_WIDTH : positive := 6 
        );
        Port ( --clk : in std_logic;
            A : in std_logic_vector (G_DATA_WIDTH-1 downto 0);
            C : out std_logic_vector (G_COUNT_WIDTH-1 downto 0);
            V : out std_logic
        );
    end component;
    
    component barrel_sl is
        Generic ( 
            constant G_DATA_WIDTH : positive := 64;
            constant G_SHIFT_SIZE : positive := 6 
        );
        Port ( --clk : in std_logic;
            A : in std_logic_vector (G_DATA_WIDTH-1 downto 0);
            shamt : in std_logic_vector (G_SHIFT_SIZE-1 downto 0);
            S : out std_logic_vector (G_DATA_WIDTH-1 downto 0)
        );
    end component;
    
    
    component barrel_slc is
        Generic ( 
            constant G_DATA_WIDTH : positive := 32;
            constant G_SHIFT_SIZE : positive := 5 
        );
        Port ( --clk : in std_logic;
            A : in std_logic_vector (G_DATA_WIDTH-1 downto 0);
            shamt : in std_logic_vector (G_SHIFT_SIZE-1 downto 0);
            SH : out std_logic_vector (G_DATA_WIDTH-1 downto 0);
            SL : out std_logic_vector (G_DATA_WIDTH-1 downto 0)
        );
    end component;
    
    
    component barrel_sre is
        Generic ( 
            constant G_DATA_WIDTH : positive := 512;
            constant G_SHIFT_SIZE : positive := 9 
        );
        Port ( --clk : in std_logic;
            A : in std_logic_vector (G_DATA_WIDTH-1 downto 0);
            shamt : in std_logic_vector (G_SHIFT_SIZE-1 downto 0);
            S : out std_logic_vector (G_DATA_WIDTH-1 downto 0)
        );
    end component;
    
    component barrel_sr is
    Generic ( 
        constant G_DATA_WIDTH : positive := 64;
        constant G_SHIFT_SIZE : positive := 6 
    );
    Port ( --clk : in std_logic;
        A : in std_logic_vector (G_DATA_WIDTH-1 downto 0);
        shamt : in std_logic_vector (G_SHIFT_SIZE-1 downto 0);
        S : out std_logic_vector (2*G_DATA_WIDTH-1 downto 0)
    );
    end component;
    
    component posit_decode is
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
    end component;
    
    component posit_mult is
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
            s_nar : out std_logic );
    end component;

    component posit_add is
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
    end component;

    component posit_encode is
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
    end component;

    function log2(A: integer) return integer;
    function ceil_log2(Arg: integer) return integer; 
    function is_zero(d : std_logic_vector) return std_logic;
    function is_not_zero(d : std_logic_vector) return std_logic;
    function notx(d : std_logic_vector) return boolean;
    
end posit_Pkg;

package body posit_Pkg is

    function log2(A: integer) return integer is
    begin
        for I in 1 to 30 loop  -- Works for up to 32 bit integers
            if(2**I > A) then return(I-1);  end if;
        end loop;
        return(30);
    end;
    
    function ceil_log2(Arg: integer) return integer is
        variable RetVal: integer;
    begin
        RetVal := log2(Arg);
        if (Arg > (2**RetVal)) then
            return(RetVal + 1);
        else
            return(RetVal); 
        end if;
    end;
    
-- Check for ones in the vector
    function is_not_zero(d : std_logic_vector) return std_logic is
        variable z : std_logic_vector(d'range);
    begin
        z := (others => '0');
        if notx(d) then

            if d = z then
                return '0';
            else
                return '1';
            end if;

        else
            return '0';
        end if;
    end;

-- Check for ones in the vector
    function is_zero(d : std_logic_vector) return std_logic is
    begin
        return not is_not_zero(d);
    end;


-- Unary NOT X test
    function notx(d : std_logic_vector) return boolean is
        variable res : boolean;
    begin
        res := true;
-- pragma translate_off
        res := not is_x(d);
-- pragma translate_on
        return (res);
    end;   
    
end posit_Pkg;
