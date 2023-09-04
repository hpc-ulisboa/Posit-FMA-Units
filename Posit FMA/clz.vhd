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


entity clz is
    Generic ( 
        constant G_DATA_WIDTH : positive := 64;
        constant G_COUNT_WIDTH : positive := 6 
    );
    Port ( --clk : in std_logic;
        A : in std_logic_vector (G_DATA_WIDTH-1 downto 0);
        C : out std_logic_vector (G_COUNT_WIDTH-1 downto 0);
        V : out std_logic
    );
end clz;

architecture Behavioral of clz is

    function clz4(constant a : std_logic_vector(3 downto 0)) return std_logic_vector is
        variable ret : std_logic_vector(2 downto 0) := "000";
    begin
      
      if a(3) = '1' then ret := "000";
      elsif a(3 downto 2) = "01" then ret := "001"; 
      elsif a(3 downto 1) = "001" then ret := "010";
        elsif a(3 downto 0) = "0001" then ret := "011";  
      else ret := "100"; end if;
      
      return ret;  
    end function clz4;
    
    function clz8(constant a : std_logic_vector(7 downto 0)) return std_logic_vector is
        variable ret : std_logic_vector(3 downto 0) := "0000";
        variable c1, c0: std_logic_vector(2 downto 0); 
    begin
      
      c1 := clz4(a(7 downto 4));
      c0 := clz4(a(3 downto 0));
      
      if c1(2) = '0' then
        ret(2 downto 0) := '0' & c1(1 downto 0);
      elsif c1(2) = '1' and c0(2) = '0' then
        ret(2 downto 0) := '1' & c0(1 downto 0);
      end if;
      
      ret(3) := c1(2) and c0(2);
      
      return ret;  
    end function clz8;
    
    function clz16(constant a : std_logic_vector(15 downto 0)) return std_logic_vector is
        variable ret : std_logic_vector(4 downto 0) := "00000";
        variable c1, c0: std_logic_vector(3 downto 0); 
    begin
      
      c1 := clz8(a(15 downto 8));
      c0 := clz8(a(7 downto 0));
      
      if c1(3) = '0' then
        ret(3 downto 0) := '0' & c1(2 downto 0);
      elsif c1(3) = '1' and c0(3) = '0' then
        ret(3 downto 0) := '1' & c0(2 downto 0);
      end if;
      
      ret(4) := c1(3) and c0(3);
      
      return ret;  
    end function clz16;
    
    function clz32(constant a : std_logic_vector(31 downto 0)) return std_logic_vector is
        variable ret : std_logic_vector(5 downto 0) := "000000";
        variable c1, c0: std_logic_vector(4 downto 0); 
    begin
      
      c1 := clz16(a(31 downto 16));
      c0 := clz16(a(15 downto 0));
      
      if c1(4) = '0' then
        ret(4 downto 0) := '0' & c1(3 downto 0);
      elsif c1(4) = '1' and c0(4) = '0' then
        ret(4 downto 0) := '1' & c0(3 downto 0);
      end if;
      
      ret(5) := c1(4) and c0(4);
      
      return ret;  
    end function clz32;
    
    function clz64(constant a : std_logic_vector(63 downto 0)) return std_logic_vector is
        variable ret : std_logic_vector(6 downto 0) := "0000000";
        variable c1, c0: std_logic_vector(5 downto 0); 
    begin
      
      c1 := clz32(a(63 downto 32));
      c0 := clz32(a(31 downto 0));
      
      if c1(5) = '0' then
        ret(5 downto 0) := '0' & c1(4 downto 0);
      elsif c1(5) = '1' and c0(5) = '0' then
        ret(5 downto 0) := '1' & c0(4 downto 0);
      end if;
      
      ret(6) := c1(5) and c0(5);
      
      return ret;  
    end function clz64;

    function clz128(constant a : std_logic_vector(127 downto 0)) return std_logic_vector is
        variable ret : std_logic_vector(7 downto 0) := "00000000";
        variable c1, c0: std_logic_vector(6 downto 0); 
    begin
      
      c1 := clz64(a(127 downto 64));
      c0 := clz64(a(63 downto 0));
      
      if c1(6) = '0' then
        ret(6 downto 0) := '0' & c1(5 downto 0);
      elsif c1(6) = '1' and c0(6) = '0' then
        ret(6 downto 0) := '1' & c0(5 downto 0);
      end if;
      
      ret(7) := c1(6) and c0(6);
      
      return ret;  
    end function clz128;
    
    function clz256(constant a : std_logic_vector(255 downto 0)) return std_logic_vector is
        variable ret : std_logic_vector(8 downto 0) := "000000000";
        variable c1, c0: std_logic_vector(7 downto 0); 
    begin
      
      c1 := clz128(a(255 downto 128));
      c0 := clz128(a(127 downto 0));
      
      if c1(7) = '0' then
        ret(7 downto 0) := '0' & c1(6 downto 0);
      elsif c1(7) = '1' and c0(7) = '0' then
        ret(7 downto 0) := '1' & c0(6 downto 0);
      end if;
      
      ret(8) := c1(7) and c0(7);
      
      return ret;  
    end function clz256;
    
    function clz512(constant a : std_logic_vector(511 downto 0)) return std_logic_vector is
        variable ret : std_logic_vector(9 downto 0) := "0000000000";
        variable c1, c0: std_logic_vector(8 downto 0); 
    begin
      
      c1 := clz256(a(511 downto 256));
      c0 := clz256(a(255 downto 0));
      
      if c1(8) = '0' then
        ret(8 downto 0) := '0' & c1(7 downto 0);
      elsif c1(8) = '1' and c0(8) = '0' then
        ret(8 downto 0) := '1' & c0(7 downto 0);
      end if;
      
      ret(9) := c1(8) and c0(8);
      
      return ret;  
    end function clz512;
    
    function clz1024(constant a : std_logic_vector(1023 downto 0)) return std_logic_vector is
        variable ret : std_logic_vector(10 downto 0) := "00000000000";
        variable c1, c0: std_logic_vector(9 downto 0); 
    begin
      
      c1 := clz512(a(1023 downto 512));
      c0 := clz512(a(511 downto 0));
      
      if c1(9) = '0' then
        ret(9 downto 0) := '0' & c1(8 downto 0);
      elsif c1(9) = '1' and c0(9) = '0' then
        ret(9 downto 0) := '1' & c0(8 downto 0);
      end if;
      
      ret(10) := c1(9) and c0(9);
      
      return ret;  
    end function clz1024;
    
    function clz2048(constant a : std_logic_vector(2047 downto 0)) return std_logic_vector is
        variable ret : std_logic_vector(11 downto 0) := "000000000000";
        variable c1, c0: std_logic_vector(10 downto 0); 
    begin
      
      c1 := clz1024(a(2047 downto 1024));
      c0 := clz1024(a(1023 downto 0));
      
      if c1(10) = '0' then
        ret(10 downto 0) := '0' & c1(9 downto 0);
      elsif c1(10) = '1' and c0(10) = '0' then
        ret(10 downto 0) := '1' & c0(9 downto 0);
      end if;
      
      ret(11) := c1(10) and c0(10);
      
      return ret;  
    end function clz2048;
        
    signal r : std_logic_vector (G_COUNT_WIDTH downto 0);
begin
    
    assert(G_DATA_WIDTH = 2048 or G_DATA_WIDTH = 1024 or G_DATA_WIDTH = 512 or G_DATA_WIDTH = 256 or G_DATA_WIDTH = 128 or G_DATA_WIDTH = 64 or G_DATA_WIDTH = 32 or G_DATA_WIDTH = 16 or G_DATA_WIDTH = 8 or G_DATA_WIDTH = 4);
    
    clz2048_gen: if G_DATA_WIDTH = 2048 generate
            assert (G_DATA_WIDTH = 64 and G_COUNT_WIDTH = 11);
            r <= clz2048(A);
        end generate;
        
    clz1024_gen: if G_DATA_WIDTH = 1024 generate
        assert (G_DATA_WIDTH = 1024 and G_COUNT_WIDTH = 10);
        r <= clz1024(A);
    end generate;
        
    clz512_gen: if G_DATA_WIDTH = 512 generate
        assert (G_DATA_WIDTH = 512 and G_COUNT_WIDTH = 9);
        r <= clz512(A);
    end generate;
    
    clz256_gen: if G_DATA_WIDTH = 256 generate
        assert (G_DATA_WIDTH = 256 and G_COUNT_WIDTH = 8);
        r <= clz256(A);
    end generate;        
            
    clz128_gen: if G_DATA_WIDTH = 128 generate
        assert (G_DATA_WIDTH = 128 and G_COUNT_WIDTH = 7);
        r <= clz128(A);
    end generate;
                
                
    clz64_gen: if G_DATA_WIDTH = 64 generate
        assert (G_DATA_WIDTH = 64 and G_COUNT_WIDTH = 6);
        r <= clz64(A);
    end generate;
    
    
    clz32_gen: if G_DATA_WIDTH = 32 generate
        assert (G_DATA_WIDTH = 32 and G_COUNT_WIDTH = 5);
        r <= clz32(A);
    end generate;

    
    clz16_gen: if G_DATA_WIDTH = 16 generate
        assert (G_DATA_WIDTH = 16 and G_COUNT_WIDTH = 4);
        r <= clz16(A);
    end generate;
    
   
    clz8_gen: if G_DATA_WIDTH = 8 generate
         assert (G_DATA_WIDTH = 8 and G_COUNT_WIDTH = 3);
         r <= clz8(A);
    end generate;
        
    
    clz4_gen: if G_DATA_WIDTH = 4 generate
        assert (G_DATA_WIDTH = 4 and G_COUNT_WIDTH = 2);
        r <= clz4(A);
    end generate;       
    
    C <= r(G_COUNT_WIDTH-1 downto 0);
    V <= r(G_COUNT_WIDTH);
    
--    seq: process(clk)

--    begin
--        if rising_edge(clk) then
--           C <= r(G_COUNT_WIDTH-1 downto 0);
--           V <= r(G_COUNT_WIDTH);
--        end if;
--    end process;
    
end Behavioral;
