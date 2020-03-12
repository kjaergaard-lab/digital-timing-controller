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
			
			pulseOut	:	out	std_logic_vector(NUM_FLEX_TRIG-1 downto 0)
			);
end FlexDDSControl;

architecture Behavioral of FlexDDSControl is

component PulseGen is
	generic(FIXED_DUTY	:	boolean	:=	true);
	port( 	clk			:	in	std_logic;	--50 MHz clock
			period		:	in	integer;	--Period of pulses
			widthIn		:	integer;	--Width of pulses
			trig		:	in	std_logic;	--Input trigger
			trig_done	:	out	std_logic;	--Goes high when pulse sequence is finished
			pulse_out	:	out	std_logic;	--Pulse output
			Npulses		:	in	integer);	--Number of pulses
end component;



signal period	:	int_array(NUM_FLEX_TRIG-1 downto 0)	:=	(others => 200);
signal pulseWidth:	int_array(NUM_FLEX_TRIG-1 downto 0)	:=	(others => 100);
signal numPulses:	int_array(NUM_FLEX_TRIG-1 downto 0)	:=	(others => 1000000);

begin

FlexDDSGenerate:
for I in 0 to NUM_FLEX_TRIG-1 generate
	FlexDDSTrigX: PulseGen
		generic map(
			FIXED_DUTY 	=> 	true
		)
		port map(
			clk			=>	clk,
			period		=>	period(I),
			widthIn		=>	pulseWidth(I),
			trig		=>	trigIn,
			trig_done	=>	open,
			pulse_out	=>	pulseOut(I),
			Npulses		=>	numPulses(I)
		);
end generate FlexDDSGenerate;


------------------------------------------
-------------  Serial parsing  -----------
------------------------------------------
ParseSerialData: process(clk,dataReady) is
begin
	if rising_edge(clk) then
		if dataReady = '1' then
			if cmdData(31 downto 24) = ID then				
				PulseSettings: case cmdData(7 downto 0) is
					when X"00" => getParam(numFlag,numData,period,cmdData(15 downto 8));		--FlexDDS period for triggers
					when X"01" => getParam(numFlag,numData,numPulses,cmdData(15 downto 8));		--FlexDDS number of trigger pulses
						
					when others => null;
				end case;
			end if;
		end if;
	end if;
end process;

end Behavioral;

