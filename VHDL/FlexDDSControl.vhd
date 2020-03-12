library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.Constants.all;


entity FlexDDSControl is
	generic( ID			:	std_logic_vector(7 downto 0));
	
	port(	clk			:	in	std_logic;						--Input clock
			trigIn		:	in	std_logic;						--Input trigger (high for 1 cycle)
	
			dataReady	:	in	std_logic;						--New data is valid
			cmdData		:	in	std_logic_vector(31 downto 0);	--Command data
			numData		:	in	std_logic_vector(31 downto 0);	--Numerical data
			numFlag		:	inout std_logic;					--Flag to indicate that data is numerical
			
			pulseOut1	:	out	std_logic;							--
			pulseOut2	:	out	std_logic;							--
			pulseOut3	:	out	std_logic							--	
			);
end FlexDDSControl;

architecture Behavioral of FlexDDSControl is

component PulseGen is
	port( clk	:	in	std_logic;
			period	:	in	integer;
			pulse_width	:	integer;
			trig	:	in	std_logic;
			trig_done	:	out	std_logic;
			pulse_out	:	out	std_logic;
			Npulses	:	in	integer);
end component;


signal period1, period2, period3	:	integer	:=	200;
signal width1, width2, width3		:	integer	:=	100;
signal numPulses1, numPulses2, numPulses3		:	integer	:=	1000000;

begin

width1 <= period1/2;
width2 <= period2/2;
width3 <= period3/2;

FlexDDSTrig1: PulseGen port map(
	clk => clk,
	period => period1,
	pulse_width	=> width1,
	trig	=> trigIn,
	trig_done => open,
	pulse_out => pulseOut1,
	Npulses => numPulses1);
	
FlexDDSTrig2: PulseGen port map(
	clk => clk,
	period => period2,
	pulse_width	=> width2,
	trig	=> trigIn,
	trig_done => open,
	pulse_out => pulseOut2,
	Npulses => numPulses2);
	
FlexDDSTrig3: PulseGen port map(
	clk => clk,
	period => period3,
	pulse_width	=> width3,
	trig	=> trigIn,
	trig_done => open,
	pulse_out => pulseOut3,
	Npulses => numPulses3);


------------------------------------------
-------------  Serial parsing  -----------
------------------------------------------
ParseSerialData: process(clk,dataReady) is
begin
	if rising_edge(clk) then
		if dataReady = '1' then
			if cmdData(31 downto 24) = ID then				
				PulseSettings: case cmdData(7 downto 0) is
					when X"00" => getParam(numFlag,numData,period1);		--FlexDDS period for trigger 1
					when X"01" => getParam(numFlag,numData,numPulses1);	--FlexDDS number of pulses for trigger 1
					
					when X"02" => getParam(numFlag,numData,period2);		--FlexDDS period for trigger 2
					when X"03" => getParam(numFlag,numData,numPulses2);	--FlexDDS number of pulses for trigger 2
					
					when X"04" => getParam(numFlag,numData,period3);		--FlexDDS period for trigger 3
					when X"05" => getParam(numFlag,numData,numPulses3);	--FlexDDS number of pulses for trigger 3
						
					when others => null;
				end case;
			end if;
		end if;
	end if;
end process;

end Behavioral;

