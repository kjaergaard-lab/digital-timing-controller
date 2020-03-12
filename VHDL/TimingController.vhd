library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.Constants.all; 


entity TimingController is
	generic(ID				:	std_logic_vector(7 downto 0));
	port(	clk				:	in	std_logic;
			
			--Serial data signals
			cmdData			:	in	std_logic_vector(31 downto 0);
			dataReady		:	in	std_logic;
			numData			:	in	std_logic_vector(31 downto 0);
			memData			:	in	mem_data;
			dataFlag			:	inout	std_logic_vector(1 downto 0) := "00";
			
			dataToSend		:	out std_logic_vector(31 downto 0);
			transmitTrig	:	out std_logic;
			
			auxOut	:	out std_logic_vector(7 downto 0);
			
			--Physical signals
			trigIn	:	in std_logic;
			dOut	:	out std_logic_vector(31 downto 0);
			dIn		:	in	std_logic_vector(7 downto 0));
end TimingController;

architecture Behavioral of TimingController is

component BlockMemoryController is
	port(	clk	:	in	std_logic;
			--Write signals
			memWriteTrig	:	in	std_logic;
			memWriteAddr	:	in	mem_addr;
			dataIn			:	in	mem_data;
			
			--Read signals
			memReadTrig		:	in	std_logic;
			memReadAddr		:	in	mem_addr;
			memDataValid	:	out	std_logic;
			dataOut			:	out	mem_data);
end component;

------------------------------------------
----------   Memory Signals   ------------
------------------------------------------
signal maxMemAddr					:	mem_addr	:=	(others => '0');
signal memWriteTrig, memReadTrig	:	std_logic	:=	'0';
signal memWriteAddr, memReadAddr	:	mem_addr	:=	(others => '0');
signal memWriteData, memReadData	:	mem_data	:= 	(others => '0');
signal memDataValid					:	std_logic	:=	'0';

------------------------------------------------------------------------------------
--------------     Sample generator signals      -----------------------------------
------------------------------------------------------------------------------------
constant sampleTime	:	integer range 0 to 4	:=	4;
signal sampleCount	:	integer range 0 to 4	:=	0;
signal sampleTick		:	std_logic	:=	'0';


signal seqEnabled, seqRunning, seqDone	:	std_logic	:=	'0';
signal seqStart, seqStop	:	std_logic	:=	'0';

-----------------------------------------------------
----------   Parse Instruction Signals   ------------
-----------------------------------------------------
constant INSTR_WAIT	:	std_logic_vector(7 downto 0)	:=	X"00";
constant INSTR_OUT	:	std_logic_vector(7 downto 0)	:=	X"01";
constant INSTR_IN	:	std_logic_vector(7 downto 0)	:=	X"02";

signal parseState	:	integer range 0 to 7	:=	0;


----------------------------------------------
--------  Delay Generator Signals   ----------
----------------------------------------------
signal waitTime		:	integer	:=	10;
signal delayCount	:	integer	:=	0;

----------------------------------------------
----------  Digital Out Signals   ------------
----------------------------------------------
signal dOutSig		:	digital_output_bank	:=	(others => '0');
signal dOutManual	:	digital_output_bank	:=	(others => '0');

----------------------------------------------
----------  Digital In Signals   -------------
----------------------------------------------
-- constant trigRisingEdge	:	std_logic_vector(1 downto 0)	:=	"01";
-- constant trigFallingEdge	:	std_logic_vector(1 downto 0)	:=	"10";

-- signal waitForDigitalIn, trigWaitDone	:	std_logic	:=	'0';
-- signal trigSync	:	std_logic_vector(1 downto 0)	:=	"00";
-- signal trigBit	:	integer range 0 to 7	:=	0;
-- signal trigType	:	integer range 0 to 2	:=	0;
-- signal trigInState	:	integer range 0 to 1	:=	0;


begin

TimingMemory: BlockMemoryController PORT MAP(
	clk 			=> clk,
	memWriteTrig 	=> memWriteTrig,
	memWriteAddr 	=> memWriteAddr,
	dataIn 			=> memWriteData,
	memReadTrig 	=> memReadTrig,
	memReadAddr 	=> memReadAddr,
	memDataValid 	=> memDataValid,
	dataOut 		=> memReadData
);

dOut <= dOutSig when seqRunning = '1' else dOutManual;

-- auxOut(0) <= masterEnable;
-- auxOut(1) <= sampleTick;
-- auxOut(2) <= waitEnable;
-- auxOut(3) <= seqStart;
-- auxOut(5 downto 4) <= dataFlag;
-- auxOut(7 downto 6) <= (others => '0');

--
-- Generates sample clock
--
SampleGenerator: process(clk) is
begin
	if rising_edge(clk) then
		if sampleCount = 0 then
			if seqRunning = '1' or (trigIn = '1' and seqEnabled = '1') then
				sampleCount <= 1;
				sampleTick <= '1';
			else
				sampleTick <= '0';
			end if;
		elsif sampleCount < (sampleTime-1) then
			sampleTick <= '0';
			sampleCount <= sampleCount + 1;
		else
			sampleTick <= '0';
			sampleCount <= 0;
		end if;
		
--		if seqRunning = '1' or (trigIn = '1' and seqEnabled = '1') then	
--			if sampleCount < sampleTime then
--				sampleCount <= sampleCount + 1;
--				sampleTick <= '0';
--			else
--				sampleCount <= 0;
--				sampleTick <= '1';
--			end if;
--		else
--			sampleCount <= sampleTime;
--			sampleTick <= '0';
--		end if;
	end if;
end process;


MainProcess: process(clk) is
begin
	if rising_edge(clk) then
		if seqStop = '1' then
			parseState <= 0;
		else
			MainFSM: case parseState is
				--
				-- Wait for start signal
				--
				when 0 =>
					if seqStart = '1' then
						parseState <= 1;
						memReadTrig <= '1';
						seqEnabled <= '1';
					else
						memReadAddr <= (others => '0');
						seqEnabled <= '0';
						memReadTrig <= '0';
						seqDone <= '0';
						seqRunning <= '0';
					end if;

				--
				-- Wait for trigger or continue if sequence is running
				--
				when 1 =>
	--				if seqDone = '1' then
	--					memReadTrig <= '1';
	--					seqDone <= '0';
	--					parseState <= 0;
	--					seqRunning <= '0';
	--				else
						memReadTrig <= '0';
						parseState <= 2;
	--				end if;

				--
				-- Parse instruction
				--
				when 2 =>
					if sampleTick = '1' and seqDone = '1' then
						memReadTrig <= '1';
						seqDone <= '0';
						parseState <= 1;
						seqRunning <= '0';
					elsif sampleTick = '1' then
						if memReadAddr < maxMemAddr then
							memReadTrig <= '1';
							memReadAddr <= memReadAddr + X"1";
							seqRunning <= '1';
						else
							memReadAddr <= (others => '0');
							seqDone <= '1';
						end if;

						InstrOptions: case memReadData(8*NUM_MEM_BYTES-1 downto 8*(NUM_MEM_BYTES-1)) is
							when INSTR_WAIT =>
								waitTime <= to_integer(unsigned(memReadData(31 downto 0)));	
								delayCount <= 0;
								parseState <= 3;					
								
							when INSTR_OUT =>
								dOutSig <= memReadData(31 downto 0);
								parseState <= 2;
								
							-- when INSTR_IN =>
							-- 	waitEnable <= '1';
							-- 	waitForDigitalIn <= '1';
							-- 	trigBit <= to_integer(unsigned(memReadData(7 downto 0)));
							-- 	trigType <= to_integer(unsigned(memReadData(8*(MemBytes-1)-1 downto 8*(MemBytes-2))));
							-- 	parseState <= 4;

							when others => parseState <= 1;
						end case;
					else
						memReadTrig <= '0';
					end if;

				--
				-- Delay state
				--
				when 3 =>
					memReadTrig <= '0';
					if sampleTick = '1' and delayCount < (waitTime - 2) then
						delayCount <= delayCount + 1;
					elsif delayCount = (waitTime - 2) then
						parseState <= 2;
					end if;
						
				-- --
				-- -- Wait-for-trigger state
				-- --
				-- when 4 =>
					


				when others => null;
			end case;
		end if;
	end if;
end process;


-- InputTriggerDetector: process(clk) is
-- begin
-- 	if rising_edge(clk) then
-- 		DigitalInFSM: case trigInState is
-- 			when 0 =>
-- 				trigWaitDone <= '0';
-- 				if waitForDigitalIn = '1' then
-- 					trigInState <= 1;
-- 					trigSync <= dIn(trigBit) & dIn(trigBit);
-- 				else
-- 					trigInstate <= 0;
-- 				end if;
				
-- 			when 1 =>
-- 				trigSync <= trigSync(0) & dIn(trigBit);
-- 				TrigTypeCase: case trigType is
-- 					--Falling edge
-- 					when 0 =>
-- 						if trigSync = trigFallingEdge then
-- 							trigInState <= 0;
-- 							trigWaitDone <= '1';
-- 						end if;
						
-- 					--Either a rising or falling edge
-- 					when 1 =>
-- 						if trigSync = trigFallingEdge or trigSync = trigRisingEdge then
-- 							trigInState <= 0;
-- 							trigWaitDone <= '1';
-- 						end if;
						
-- 					--Rising edge
-- 					when 2 =>
-- 						if trigSync = trigRisingEdge then
-- 							trigInState <= 0;
-- 							trigWaitDone <= '1';
-- 						end if;
-- 					when others => null;
-- 				end case;	--end TrigTypeCase
-- 			when others => null;
-- 		end case;	--end DigitalInFSM
-- 	end if;
-- end process;


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
							dataToSend(31 downto 30) <= (seqEnabled & seqRunning);
							dataToSend(MEM_ADDR_WIDTH-1 downto 0) <= std_logic_vector(memReadAddr);
						when X"03" =>
							transmitTrig <= '1';
							dataToSend <= dOutManual;
						when others => null;
					end case;	--end SoftTrigs
				
				--Manual digital outputs
				when X"01" => getParam(dataFlag(0),numData,dOutManual);
--					if dataFlag(0) = '0' then
--						dataFlag(0) <= '1';
--					else
--						dataFlag(0) <= '0';
--						dOutManual <= numData;
--					end if;
					
				
				--Memory uploading
				when X"02" =>
					if dataFlag(1) = '0' then
						maxMemAddr <= unsigned(cmdData(MEM_ADDR_WIDTH-1 downto 0));
						memWriteAddr <= (others => '0');
						dataFlag(1) <= '1';
					elsif dataFlag(1) = '1' and memWriteAddr < maxMemAddr then
						memWriteData <= memData;
						memWriteTrig <= '1';
					elsif dataFlag(1) = '1' and memWriteAddr >= maxMemAddr then
						memWriteData <= memData;
						memWriteTrig <= '1';
						dataFlag(1) <= '0';
					end if;
						
					
				when others => null;
			end case;	--end SerialOptions
			
		else
			if memWriteTrig = '1' then
				memWriteTrig <= '0';
				memWriteAddr <= memWriteAddr + X"1";
			end if;
			seqStart <= '0';
			seqStop <= '0';
			transmitTrig <= '0';
			reset <= '0';
		end if;	--end dataReady
	end if;	--end rising_edge(clk)
end process;


end Behavioral;

