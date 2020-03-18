library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.Constants.all; 

entity topmod is
	port (		clk50x	:	in	std_logic;
				-- clkExt	:	in	std_logic;
				trigIn		:	in	std_logic;
				trigEnable	:	in	std_logic;

				--
				-- Serial data signals
				--
				ledvec	:	out	std_logic_vector(7 downto 0);
				TxD		:	out	std_logic;
				RxD		:	in	std_logic;
				
				--Regular imaging
				camTrigOut		:	out	std_logic;
				
				probeInRb		:	in	std_logic;
				shutterInRb		:	in	std_logic;
				probeOutRb		:	out	std_logic;
				shutterOutRb	:	out	std_logic;	
				
				probeInK		:	in	std_logic;
				shutterInK		:	in	std_logic;
				probeOutK		:	out	std_logic;
				shutterOutK		:	out	std_logic;		
				
				--Vertical imaging
				probeOutV		:	out	std_logic;
				shutterOutV		:	out	std_logic;
				camTrigInV		:	in	std_logic;
				camTrigOutV		:	out	std_logic;
				
				--Fluorescence imaging
				probeInF		:	in	std_logic_vector(1 downto 0);		--(MOT,Repump)
				probeOutF		:	out	std_logic_vector(1 downto 0);		--(MOT,Repump)
				shutterInF		:	in	std_logic_vector(1 downto 0);		--(MOT,Repump)
				shutterOutF		:	out	std_logic_vector(1 downto 0);		--(MOT,Repump)

				--Trapping laser
				trapLaserOut	:	out	std_logic;	
				
				--Coil output
				coilOut			:	out	std_logic;

				--State preparation
				inMW			:	in	std_logic;
				outMW			:	out	std_logic;
				outRF			:	out	std_logic;
				outPulseType	:	out	std_logic;
				
				--FlexDDS triggers
				FlexDDSOut		:	out	std_logic_vector(NUM_FLEX_TRIG-1 downto 0)

				-- dOut		:	out std_logic_vector(31 downto 0);
				-- dIn			:	in	std_logic_vector(7 downto 0)
			);	
end topmod;

architecture Behavioral of topmod is

-------------------------------------------------------
-----------------  Clock Components  ------------------
-------------------------------------------------------
component DCM1
PORT(
		CLKIN_IN : IN std_logic;          
		CLKIN_IBUFG_OUT : OUT std_logic;
		CLK0_OUT : OUT std_logic;
		CLK2X_OUT : OUT std_logic
		);
end component;

-------------------------------------------------------
----------  Serial Communication Components  ----------
-------------------------------------------------------
component SerialCommunication
	generic (baudPeriod	:	integer;				--Baud period appropriate for clk
	numMemBytes	:	integer);				--Number of bytes in mem data			
	port(	clk 				: 	in  std_logic;		--Clock signal

	--Signals for reading from serial port
	RxD				:	in	std_logic;									--Input RxD from a UART signal
	cmdDataOut		:	out std_logic_vector(31 downto 0);				--32 bit command word
	numDataOut		:	out std_logic_vector(31 downto 0);				--Numerical parameter
	memDataOut		:	out std_logic_vector(8*numMemBytes-1 downto 0);	--Data for memory
	dataFlag		:	in	std_logic_vector(1 downto 0);				--Indicates type of data (mem, num)
	dataReady		:	out 	std_logic;								--Flag to indicate that data is valid

	--Signals for transmitting on serial port
	TxD				:	out std_logic;									--Serial transmit pin
	dataIn			:	in  std_logic_vector(31 downto 0);				--Data to transmit
	transmitTrig	:	in  std_logic;									--Trigger to start transmitting data
	transmitBusy	:	out std_logic);									--Flag to indicate that a transmission is in progress
end component;

component TimingController is
	generic(	ID	:	std_logic_vector(7 downto 0));
	port(	clk			:	in	std_logic;
			
			--Serial data signals
			cmdData			:	in	std_logic_vector(31 downto 0);
			dataReady		:	in	std_logic;
			numData			:	in	std_logic_vector(31 downto 0);
			memData			:	in	mem_data;
			dataFlag		:	inout	std_logic_vector(1 downto 0);
			
			dataToSend		:	out std_logic_vector(31 downto 0);
			transmitTrig	:	out std_logic;
			
			auxOut	:	out std_logic_vector(7 downto 0);
			
			--Physical signals
			trigIn	:	in std_logic;
			dOut	:	out digital_output_bank;
			dIn		:	in	digital_input_bank);
end component;

component FlexDDSControl is
	generic( ID			:	std_logic_vector(7 downto 0));
	
	port(	clk			:	in	std_logic;						--Input clock
			trigIn		:	in	std_logic;						--Input trigger (high for 1 cycle)
	
			dataReady	:	in	std_logic;						--New data is valid
			cmdData		:	in	std_logic_vector(31 downto 0);	--Command data
			numData		:	in	std_logic_vector(31 downto 0);	--Numerical data
			numFlag		:	inout std_logic;					--Flag to indicate that data is numerical
			
			pulseOut	:	out	std_logic_vector(NUM_FLEX_TRIG-1 downto 0)
			);
end component;


signal clk50, clk100, clk	:	std_logic;

------------------------------------------------------------------------------------
----------------------Serial interface signals--------------------------------------
------------------------------------------------------------------------------------
signal dataReady		:	std_logic	:=	'0';	--signal from ReadData that says new 32-bit word is ready
signal cmdData, numData	:	std_logic_vector(31 downto 0)	:=	(others => '0');	--command word

signal dataToSend		:	std_logic_vector(31 downto 0)	:=	(others => '0');
signal transmitBusy		:	std_logic;
signal transmitTrig		:	std_logic	:=	'0';

signal memData			:	mem_data	:=	(others => '0');
signal dataFlag, dataFlag0, dataFlag1, dataFlagFF	:	std_logic_vector(1 downto 0)	:=	"00";



------------------------------------------------------------------------------------
----------------------     Other signals      --------------------------------------
------------------------------------------------------------------------------------
signal trigSync			:	std_logic_vector(1 downto 0)	:=	"00";
signal trig, startTrig	:	std_logic	:=	'0';
constant trigHoldOff	:	integer	:=	100000000;	--1 s at 100 MHz
signal trigCount		:	integer	:=	0;

signal dOut	:	std_logic_vector(31 downto 0)	:=	(others => '0');

begin


-------------------------------------------------------
-----------------  Clock Components  ------------------
-------------------------------------------------------
Inst_dcm1: DCM1 port map (
	CLKIN_IN => clk50x,
	CLKIN_IBUFG_OUT => open,
	CLK0_OUT => clk50,
	CLK2X_OUT => clk100);
	
clk <= clk100;
	
-------------------------------------------------------
----------  Serial Communication Components  ----------
-------------------------------------------------------

dataFlag <= dataFlag0 or dataFlag1 or dataFlagFF;

SerialCommunication_inst: SerialCommunication 
generic map(baudPeriod => BAUD_PERIOD,
			numMemBytes => NUM_MEM_BYTES)
port map(
	clk => clk,
	
	RxD => RxD,
	cmdDataOut => cmdData,
	numDataOut => numData,
	memDataOut => memData,
	dataFlag => dataFlag,
	dataReady => dataReady,
	
	TxD => TxD,
	dataIn => dataToSend,
	transmitTrig => transmitTrig,
	transmitBusy => transmitBusy);
	
ledvec <= cmdData(ledvec'length-1 downto 0);

--
-- Input trigger synchronization
--
InputTrigSync: process(clk) is
begin
	if rising_edge(clk) then
		trigSync <= (trigSync(0) & (trigIn and trigEnable));
	end if;
end process;

SeqTrigTiming: process(clk) is
begin
	if rising_edge(clk) then
		if (trigSync = "01" or startTrig = '1') and trigCount = 0 then
			trig <= '1';
			trigCount <= trigCount + 1;
		elsif trigCount > 0 and trigCount < trigHoldOff then
			trig <= '0';
			trigCount <= trigCount + 1;
		else
			trig <= '0';
			trigCount <= 0;
		end if;
	end if;
end process;
	

--
-- Main digital timing controller
--
TimingControl: TimingController 
generic map(
	ID => X"00"
)
PORT MAP(
	clk 			=> 	clk,
	cmdData 		=> 	cmdData,
	dataReady 		=> 	dataReady,
	numData 		=> 	numData,
	memData 		=> 	memData,
	dataFlag 		=> 	dataFlag0,
	dataToSend 		=> 	dataToSend,
	transmitTrig	=>	transmitTrig,
	trigIn			=>	trig,
	auxOut 			=> 	open,
	dOut 			=> 	dOut,
	dIn 			=> 	(others => '0')
); 

--
-- Regular imaging
--
camTrigOut <= dOut(0);
probeOutRb <= probeInRb or dOut(1);
shutterOutRb <= shutterInRb or dOut(2);
probeOutK <= probeInK or dOut(3);
shutterOutK <= shutterInK or dOut(4);

--
-- Vertical imaging
--
probeOutV <= dOut(5);
shutterOutV <= dOut(6);
camTrigOutV <= camTrigInV or dOut(7);

--
-- Fluorescence imaging
--
probeOutF <= probeInF or dOut(9 downto 8);			--(MOT, Repump)
shutterOutF <= shutterInF or dOut(11 downto 10);	--(MOT, Repump)

--
-- Trapping laser
--
trapLaserOut <= dOut(12);

--
-- Coil output
--
coilOut <= dOut(13);

--
-- State preparation
--
outMW <= inMW or dOut(14);
outRF <= dOut(15);
outPulseType <= dOut(16);

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


FlexDDS: FlexDDSControl
generic map(
	ID	=>	X"01"
)
port map(
	clk				=>	clk,
	trigIn			=>	trig,
	cmdData 		=> 	cmdData,
	dataReady 		=> 	dataReady,
	numData 		=> 	numData,
	numFlag			=>	dataFlag1(0),
	pulseOut		=>	FlexDDSOut
);

-------------------------------------------------------
------------  Serial command parsing  -----------------
-------------------------------------------------------

TopLevelSerialParsing: process(clk) is
begin
	if rising_edge(clk) then
		if dataReady = '1' and cmdData(31 downto 24) = X"FF" then
			startTrig <= '1';
		else
			startTrig <= '0';
		end if;
	end if;
end process;
	



end Behavioral;

