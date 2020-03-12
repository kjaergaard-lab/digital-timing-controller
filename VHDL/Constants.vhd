--
--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions 
--
--   To use any of the example code shown below, uncomment the lines and modify as necessary
--

library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 

package Constants is

-- type <new_type> is
--  record
--    <type_name>        : std_logic_vector( 7 downto 0);
--    <type_name>        : std_logic;
-- end record;
--
-- Declare constants
--
-- constant <constant_name>		: time := <time_unit> ns;
constant BAUD_PERIOD		:	integer	:= 868;	--With a 100 MHz clock, corresponds to 115200 Hz

constant NUM_MEM_BYTES		:	integer	:=	5;
constant MEM_ADDR_WIDTH     :	integer	:=	11;

type int_array is array (integer range <>) of integer;
subtype mem_data is std_logic_vector(8*NUM_MEM_BYTES-1 downto 0);
subtype mem_addr is unsigned(MEM_ADDR_WIDTH-1 downto 0);
subtype digital_output_bank is std_logic_vector(31 downto 0);

type mem_data_array is array (integer range <>) of mem_data;
-- type ser_data_array is array (integer range <>) of std_logic_vector(31 downto 0);

--
-- Declare functions and procedure
--
-- function <function_name>  (signal <signal_name> : in <type_declaration>) return <type_declaration>;
-- procedure <procedure_name> (<type_declaration> <constant_name>	: in <type_declaration>);
--

end Constants;

package body Constants is

---- Example 1
--  function <function_name>  (signal <signal_name> : in <type_declaration>  ) return <type_declaration> is
--    variable <variable_name>     : <type_declaration>;
--  begin
--    <variable_name> := <signal_name> xor <signal_name>;
--    return <variable_name>; 
--  end <function_name>;

---- Example 2
--  function <function_name>  (signal <signal_name> : in <type_declaration>;
--                         signal <signal_name>   : in <type_declaration>  ) return <type_declaration> is
--  begin
--    if (<signal_name> = '1') then
--      return <signal_name>;
--    else
--      return 'Z';
--    end if;
--  end <function_name>;

---- Procedure Example
--  procedure <procedure_name>  (<type_declaration> <constant_name>  : in <type_declaration>) is
--    
--  begin
--    
--  end <procedure_name>;
 
end Constants;
