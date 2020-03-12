library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.Constants.all; 

entity topmod is
	port (		clk100x	:	in	std_logic;
				ledvec	:	out	std_logic_vector(7 downto 0);
				TxD		:	out	std_logic;
				RxD		:	in	std_logic;
				
				trigIn		:	in	std_logic;
				trigEnable	:	in	std_logic;
--				auxOut	:	out std_logic_vector(7 downto 0);
				dOut		:	out std_logic_vector(31 downto 0);
				dIn			:	in	std_logic_vector(7 downto 0)
			);	
end topmod;

architecture Behavioral of topmod is

-------------------------------------------------------
-----------------  Clock Components  ------------------
-------------------------------------------------------
component DCM1
port
 (-- Clock in ports
  CLK_IN1           : in     std_logic;
  -- Clock out ports
  CLK_OUT1          : out    std_logic
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
			numData			:	in	integer;
			memData			:	in	mem_data;
			dataFlag		:	inout	std_logic_vector(1 downto 0);
			
			dataToSend		:	out std_logic_vector(31 downto 0);
			transmitTrig	:	out std_logic;
			
			auxOut	:	out std_logic_vector(7 downto 0);
			
			--Physical signals
			trigIn	:	in std_logic;
			dOut	:	out std_logic_vector(31 downto 0);
			dIn		:	in	std_logic_vector(7 downto 0));
end component;


signal clk100	:	std_logic;

------------------------------------------------------------------------------------
----------------------Serial interface signals--------------------------------------
------------------------------------------------------------------------------------
signal dataReady		:	std_logic	:=	'0';	--signal from ReadData that says new 32-bit word is ready
signal cmdData, numData	:	std_logic_vector(31 downto 0)	:=	(others => '0');	--command word

signal dataToSend		:	std_logic_vector(31 downto 0)	:=	(others => '0');
signal transmitBusy		:	std_logic;
signal transmitTrig		:	std_logic	:=	'0';

signal memData			:	mem_data	:=	(others => '0');
signal dataFlag			:	std_logic_vector(1 downto 0)	:=	"00";



------------------------------------------------------------------------------------
----------------------     Other signals      --------------------------------------
------------------------------------------------------------------------------------
signal trigSync		:	std_logic_vector(1 downto 0)	:=	"00";
signal trig			:	std_logic	:=	'0';


begin


-------------------------------------------------------
-----------------  Clock Components  ------------------
-------------------------------------------------------
Inst_dcm1: DCM1 port map (
	CLK_IN1 => clk100x,
	CLK_OUT1 => clk100);
	
-------------------------------------------------------
----------  Serial Communication Components  ----------
-------------------------------------------------------
SerialCommunication_inst: SerialCommunication 
generic map(baudPeriod => BaudPeriod,
				numMemBytes => MemBytes)
port map(
	clk => clk100,
	
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
	
	

TimingControl: TimingController 
generic map(
	ID => X"00"
)
PORT MAP(
	clk 			=> clk100,
	cmdData 		=> cmdData,
	dataReady 		=> dataReady,
	numData 		=> numData,
	memData 		=> memData,
	dataFlag 		=> dataFlag,
	dataToSend 		=> dataToSend,
	transmitTrig	=>	transmitTrig,
	trigIn			=>	trig,
	auxOut 			=> open,
	dOut 			=> dOut,
	dIn 			=> dIn
); 
  

-- ledvec <= cmdData(31 downto 24);

--
-- Input trigger synchronization
--
InputTrigSync: process(clk) is
begin
	if rising_edge(clk) then
		trigSync <= (trigSync(0) & trigIn);
		if ((trigSync(0) & trigIn) = "01") and trigEnable = '1' then
			trig <= '1';
		else
			trig <= '0';
		end if;
		
	end if;
end process;


-------------------------------------------------------
------------  Serial command parsing  -----------------
-------------------------------------------------------
--auto_flag <= not(cmd_data(31));
--
--ReadProcess: process(clk100) is
--begin
--	if rising_edge(clk100) then
--		if data_ready = '1' then
--
--		end if;	--End data_ready if statement
--	end if;
--end process;
	



end Behavioral;

