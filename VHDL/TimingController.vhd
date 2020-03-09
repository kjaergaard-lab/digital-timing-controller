library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.CustomTypes.all; 


entity TimingController is
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
end TimingController;

architecture Behavioral of TimingController is


------------------------------------------
----------   Memory Signals   ------------
------------------------------------------
constant memAddrIncrement	:	unsigned(AddrWidth-1 downto 0)	:=	(0 => '1', others => '0');
signal maxMemAddr	:	unsigned(AddrWidth-1 downto 0)	:=	(others => '0');

------------------------------------------------------------------------------------
--------------     Sample generator signals      -----------------------------------
------------------------------------------------------------------------------------
constant sampleTime	:	integer	:=	4;
signal sampleCount	:	integer range 0 to 4	:=	0;
signal sampleTrig	:	std_logic	:=	'0';
signal seqState	:	integer range 0 to 2	:=	0;
signal seqStart, seqStop, masterEnable	:	std_logic	:=	'0';
signal endOfInstr	:	std_logic_vector(1 downto 0)	:=	"00";


-----------------------------------------------------
----------   Parse Instruction Signals   ------------
-----------------------------------------------------
constant waitInstr			:	std_logic_vector(7 downto 0)	:=	X"00";
constant digitalOutInstr	:	std_logic_vector(7 downto 0)	:=	X"01";
constant digitalInInstr		:	std_logic_vector(7 downto 0)	:=	X"02";

signal parseState	:	integer range 0 to 1	:=	0;
signal updateTrig	:	std_logic	:=	'0';
signal waitDone		:	std_logic	:=	'0';


----------------------------------------------
--------  Delay Generator Signals   ----------
----------------------------------------------
signal waitTime	:	integer	:=	10;
signal delayCount	:	integer	:=	0;
signal delayGenTrig, delayDone	:	std_logic	:=	'0';
signal waitEnable	:	std_logic	:=	'0';

----------------------------------------------
----------  Digital Out Signals   ------------
----------------------------------------------
signal dOutSig	:	std_logic_vector(31 downto 0)	:=	(others => '0');
signal dOutManual	:	std_logic_vector(31 downto 0)	:=	(others => '0');

----------------------------------------------
----------  Digital In Signals   -------------
----------------------------------------------
constant trigRisingEdge	:	std_logic_vector(1 downto 0)	:=	"01";
constant trigFallingEdge	:	std_logic_vector(1 downto 0)	:=	"10";

signal waitForDigitalIn, trigWaitDone	:	std_logic	:=	'0';
signal trigSync	:	std_logic_vector(1 downto 0)	:=	"00";
signal trigBit	:	integer range 0 to 7	:=	0;
signal trigType	:	integer range 0 to 2	:=	0;
signal trigInState	:	integer range 0 to 1	:=	0;


begin

dOut <= dOutSig when masterEnable = '1' else dOutManual;
waitDone <= delayDone or trigWaitDone;

auxOut(0) <= masterEnable;
auxOut(1) <= sampleTrig;
auxOut(2) <= waitEnable;
auxOut(3) <= seqStart;
auxOut(5 downto 4) <= dataFlag;
auxOut(7 downto 6) <= (others => '0');


SequenceStart: process(clk) is
begin
	if rising_edge(clk) then
		SequenceFSM: case seqState is
			when 0 =>
				if seqStart = '1' then
					updateTrig <= '1';
					seqState <= 1;
				else
					updateTrig <= '0';
				end if;
				
			when 1 =>
				updateTrig <= '0';
				if memDataValid = '1' then
					seqState <= 2;
				end if;
				
			when 2 =>
				if seqStop = '1' or endOfInstr(1) = '1' then
					masterEnable <= '0';
					seqState <= 0;
				else
					masterEnable <= '1';
				end if;
			
			when others => null;
		end case;	--end SequenceFSM
	end if;	--end rising_edge(clk)
end process;

SampleGenerator: process(clk) is
begin
	if rising_edge(clk) then
		if sampleCount < sampleTime then
			sampleCount <= sampleCount + 1;
			sampleTrig <= '0';
		else
			sampleCount <= 0;
			sampleTrig <= '1';
		end if;	--end sampleCount < sampleTime
	end if;	--end rising_edge
end process;  --end SampleGenerator


ParseInstructions: process(clk) is
begin
	if rising_edge(clk) then
		ParseFSM: case parseState is
			when 0 =>
				if sampleTrig = '1' and masterEnable = '1' and endOfInstr /= "11" then
					if memReadAddr < maxMemAddr then
						memReadTrig <= '1';
						memReadAddr <= memReadAddr + memAddrIncrement;		
					else
						endOfInstr(0) <= '1';
						memReadAddr <= (others => '0');
					end if;
					parseState <= 1;
					InstrOptions: case dataFromMem(8*MemBytes-1 downto 8*(MemBytes-1)) is
						when waitInstr =>
							waitEnable <= '1';
							delayGenTrig <= '1';
							waitTime <= to_integer(unsigned(dataFromMem(31 downto 0)));							
							
						when digitalOutInstr =>
							waitEnable <= '0';
							dOutSig <= dataFromMem(31 downto 0);
							
						when digitalInInstr =>
							waitEnable <= '1';
							waitForDigitalIn <= '1';
							trigBit <= to_integer(unsigned(dataFromMem(7 downto 0)));
							trigType <= to_integer(unsigned(dataFromMem(8*(MemBytes-1)-1 downto 8*(MemBytes-2))));

						when others => null;
					end case;	--end InstrOptions
				elsif updateTrig = '1' then
					memReadTrig <= '1';
					memReadAddr <= (others => '0');					
				else
					memReadTrig <= '0';
					waitEnable <= '0';
					delayGenTrig <= '0';
					waitForDigitalIn <= '0';
					endOfInstr <= "00";					
				end if;	--end sampleTrig = '1'
			
			when 1 =>
				memReadTrig <= '0';
				delayGenTrig <= '0';
				if waitEnable = '0' then
					parseState <= 0;
					endOfInstr(1) <= endOfInstr(0);
				elsif waitEnable = '1' and waitDone = '1' then
					parseState <= 0;
					waitEnable <= '0';
					endOfInstr(1) <= endOfInstr(0);
				elsif masterEnable = '0' then
					parseState <= 0;
					waitEnable <= '0';
				end if;
			
			when others => null;
		end case;	--end ParseFSM
	end if;	--end rising_edge(clk)
end process;	--end ParseInstructions


DelayGenerator: process(clk) is
begin
	if rising_edge(clk) then
		if delayGenTrig = '1' and delayCount = 0 then
			delayCount <= 1;
		elsif sampleTrig = '1' and delayCount > 0 and delayCount < waitTime then
			delayCount <= delayCount + 1;
		elsif sampleTrig = '1' and delayCount >= waitTime then
			delayCount <= 0;
			delayDone <= '1';
		else
			delayDone <= '0';
		end if;	--end delayGenTrig = '1'
	end if;	--end rising_edge(clk)
end process;

InputTriggerDetector: process(clk) is
begin
	if rising_edge(clk) then
		DigitalInFSM: case trigInState is
			when 0 =>
				trigWaitDone <= '0';
				if waitForDigitalIn = '1' then
					trigInState <= 1;
					trigSync <= dIn(trigBit) & dIn(trigBit);
				else
					trigInstate <= 0;
				end if;
				
			when 1 =>
				trigSync <= trigSync(0) & dIn(trigBit);
				TrigTypeCase: case trigType is
					--Falling edge
					when 0 =>
						if trigSync = trigFallingEdge then
							trigInState <= 0;
							trigWaitDone <= '1';
						end if;
						
					--Either a rising or falling edge
					when 1 =>
						if trigSync = trigFallingEdge or trigSync = trigRisingEdge then
							trigInState <= 0;
							trigWaitDone <= '1';
						end if;
						
					--Rising edge
					when 2 =>
						if trigSync = trigRisingEdge then
							trigInState <= 0;
							trigWaitDone <= '1';
						end if;
					when others => null;
				end case;	--end TrigTypeCase
			when others => null;
		end case;	--end DigitalInFSM
	end if;
end process;


SerialInstructions: process(clk) is
begin
	if rising_edge(clk) then
		if dataReady = '1' and cmdData(31 downto 24) = ID then
			SerialOptions: case cmdData(23 downto 16) is
				--Software triggers
				when X"00" =>
					SoftTrigs: case cmdData(7 downto 0) is
						when X"00" => seqStart <= '1';
						when X"01" => seqStop <= '1';
						when X"02" =>
							transmitTrig <= '1';
							dataToSend(31) <= masterEnable;
							dataToSend(AddrWidth-1 downto 0) <= std_logic_vector(memReadAddr);
						when X"03" =>
							transmitTrig <= '1';
							dataToSend <= dOutManual;
						when others => null;
					end case;	--end SoftTrigs
				
				--Manual digital outputs
				when X"01" => 
					if dataFlag(0) = '0' then
						dataFlag(0) <= '1';
					else
						dataFlag(0) <= '0';
						dOutManual <= std_logic_vector(to_signed(numData,32));
					end if;
					
				
				--Memory uploading
				when X"02" =>
					if dataFlag(1) = '0' then
						maxMemAddr <= unsigned(cmdData(AddrWidth-1 downto 0));
						memWriteAddr <= (others => '0');
						dataFlag(1) <= '1';
					elsif dataFlag(1) = '1' and memWriteAddr < maxMemAddr then
						dataToWrite <= memData;
						memWriteTrig <= '1';
					elsif dataFlag(1) = '1' and memWriteAddr >= maxMemAddr then
						dataToWrite <= memData;
						memWriteTrig <= '1';
						dataFlag(1) <= '0';
					end if;
						
					
				when others => null;
			end case;	--end SerialOptions
			
		else
			if memWriteTrig = '1' then
				memWriteTrig <= '0';
				memWriteAddr <= memWriteAddr + memAddrIncrement;
			end if;
			seqStart <= '0';
			seqStop <= '0';
			transmitTrig <= '0';
		end if;	--end dataReady
	end if;	--end rising_edge(clk)
end process;


end Behavioral;

