library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.CustomTypes.all; 

entity topmod is
	port (	clk100x	:	in	std_logic;
				ledvec	:	out	std_logic_vector(7 downto 0);
--				SW	:	in	std_logic_vector(3 downto 0);
				TxD	:	out	std_logic;
				RxD	:	in	std_logic;
				
--				auxOut	:	out std_logic_vector(7 downto 0);
				dOut		:	out std_logic_vector(31 downto 0);
				dIn		:	in	std_logic_vector(7 downto 0)
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
				numMemBytes	:	integer);			--Number of bytes in mem data			
	port(	clk 				: 	in  std_logic;		--Clock signal

			--Signals for reading from serial port
			RxD				:	in	std_logic;												--Input RxD from a UART signal
			cmdDataOut		:	out std_logic_vector(31 downto 0);					--32 bit command word
			numDataOut		:	out integer;												--Numerical parameter
			memDataOut		:	out std_logic_vector(8*numMemBytes-1 downto 0);	--Data for memory
			dataFlag			:	in	std_logic_vector(1 downto 0);						--Indicates type of data (mem, num)
			dataReady		:	out 	std_logic;											--Flag to indicate that data is valid

			--Signals for transmitting on serial port
			TxD				:	out std_logic;								--Serial transmit pin
			dataIn			:	in  std_logic_vector(31 downto 0);	--Data to transmit
			transmitTrig	:	in  std_logic;								--Trigger to start transmitting data
			transmitBusy	:	out std_logic);							--Flag to indicate that a transmission is in progress
end component;


component BlockMemoryController is
	port(	clk	:	in	std_logic;
			--Write signals
			memWriteTrig	:	in	std_logic;
			memWriteAddr	:	in	unsigned(AddrWidth-1 downto 0);
			dataIn			:	in	std_logic_vector(8*MemBytes-1 downto 0);
			
			--Read signals
			memReadTrig		:	in	std_logic;
			memReadAddr		:	in	unsigned(AddrWidth-1 downto 0);
			memDataValid	:	out	std_logic;
			dataOut			:	out	std_logic_vector(8*MemBytes-1 downto 0));
end component;

component TimingController is
	generic(	ID	:	std_logic_vector(7 downto 0));
	port(	clk	:	in	std_logic;
			
			--Serial data signals
			cmdData		:	in	std_logic_vector(31 downto 0);
			dataReady	:	in	std_logic;
			numData		:	in	integer;
			memData		:	in	std_logic_vector(8*MemBytes-1 downto 0);
			dataFlag		:	inout	std_logic_vector(1 downto 0);
			
			--Serial transmission signals
			dataToSend		:	out std_logic_vector(31 downto 0);
			transmitTrig	:	out std_logic;
			
			--Memory signals
			memWriteTrig	:	inout	std_logic;
			memWriteAddr	:	inout	unsigned(AddrWidth-1 downto 0);
			dataToWrite		:	out	std_logic_vector(8*MemBytes-1 downto 0);
			
			memReadTrig		:	out	std_logic;
			memReadAddr		:	inout	unsigned(AddrWidth-1 downto 0);
			memDataValid	:	in	std_logic;
			dataFromMem		:	in	std_logic_vector(8*MemBytes-1 downto 0);
			
			auxOut	:	out std_logic_vector(7 downto 0);
			
			--Physical signals
			dOut	:	out std_logic_vector(31 downto 0);
			dIn	:	in	std_logic_vector(7 downto 0));
end component;


signal clk100	:	std_logic;

------------------------------------------------------------------------------------
----------------------Serial interface signals--------------------------------------
------------------------------------------------------------------------------------
signal dataReady		:	std_logic	:=	'0';	--signal from ReadData that says new 32-bit word is ready
signal cmdData			:	std_logic_vector(31 downto 0)	:=	(others => '0');	--command word

signal dataToSend		:	std_logic_vector(31 downto 0)	:=	(others => '0');
signal transmitBusy	:	std_logic;
signal transmitTrig	:	std_logic	:=	'0';

signal autoFlag		:	std_logic	:= '1';	--Automatic or manual mode?
signal numData			:	integer		:= 0;		--Numerical data from ReadData

signal memData			:	std_logic_vector(8*MemBytes-1 downto 0)	:=	(others => '0');
signal dataFlag		:	std_logic_vector(1 downto 0)	:=	"00";

------------------------------------------------------------------------------------
----------------------Memory interface signals--------------------------------------
------------------------------------------------------------------------------------
signal memWriteTrig, memReadTrig, memDataValid	:	std_logic	:=	'0';
signal memReadAddr, memWriteAddr	:	unsigned(AddrWidth-1 downto 0)	:=	(others => '0');
signal memDataToWrite, dataFromMem	:	std_logic_vector(8*MemBytes-1 downto 0)	:=	(others => '0');

------------------------------------------------------------------------------------
----------------------     Other signals      --------------------------------------
------------------------------------------------------------------------------------


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
	
	
-------------------------------------------------------
----------  Timing Controller Components  -------------
-------------------------------------------------------
TimingMemory: BlockMemoryController PORT MAP(
	clk => clk100,
	memWriteTrig => memWriteTrig,
	memWriteAddr => memWriteAddr,
	dataIn => memDataToWrite,
	memReadTrig => memReadTrig,
	memReadAddr => memReadAddr,
	memDataValid => memDataValid,
	dataOut => dataFromMem
);

TimingControl: TimingController 
generic map(
	ID => X"00"
)
PORT MAP(
	clk => clk100,
	cmdData => cmdData,
	dataReady => dataReady,
	numData => numData,
	memData => memData,
	dataFlag => dataFlag,
	dataToSend => dataToSend,
	transmitTrig => transmitTrig,
	memWriteTrig => memWriteTrig,
	memWriteAddr => memWriteAddr,
	dataToWrite => memDataToWrite,
	memReadTrig => memReadTrig,
	memReadAddr => memReadAddr,
	memDataValid => memDataValid,
	dataFromMem => dataFromMem,
	auxOut => open,
	dOut => dOut,
	dIn => dIn
); 
  

ledvec <= cmdData(31 downto 24);


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

