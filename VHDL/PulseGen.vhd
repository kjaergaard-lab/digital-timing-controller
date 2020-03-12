library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.Constants.all;

--Generates a pulse train given a period, pulse width, and number of pulses.  
--This version is slightly different from versions older than 02/02/2018.
--This version does not have a synchronous trigger, and if Npulses=0
--there is no delay of 1 period before trig_done is raised
entity PulseGen is
	port( clk	:	in	std_logic;	--50 MHz clock
			period	:	in	integer;	--Period of pulses
			pulse_width	:	integer;	--Width of pulses
			trig	:	in	std_logic;	--Input trigger
			trig_done	:	out	std_logic;	--Goes high when pulse sequence is finished
			pulse_out	:	out	std_logic;	--Pulse output
			Npulses	:	in	integer);	--Number of pulses
end PulseGen;

architecture Behavioral of PulseGen is

signal cnt	:	integer	:=	0;	--Counts clock edges
signal pulse_cnt	:	integer	:= 0;	--Counts number of pulses

begin

--Generates pulse train
PulseProcess: process(clk,trig) is
	begin
		if rising_edge(clk) then
			if Npulses > 0 then
				if pulse_cnt < Npulses then
					if trig = '1' and cnt = 0 then
						cnt <= cnt + 1;
					elsif cnt >= 1 and cnt <= pulse_width then
						pulse_out <= '1';
						cnt <= cnt + 1;
					elsif cnt > pulse_width and cnt < period then
						pulse_out <= '0';
						cnt <= cnt + 1;
					elsif cnt = period then
						pulse_out <= '0';
						cnt <= 1;
						pulse_cnt <= pulse_cnt + 1;
					else
						pulse_out <= '0';
						cnt <= 0;
						pulse_cnt <= 0;
						trig_done <= '0';
					end if;
				else
					cnt <= 0;
					pulse_cnt <= 0;
					pulse_out <= '0';
					trig_done <= '1';
				end if;
			else	--If Npulses=0, then wait one clock cycle before raising trig_done
				pulse_cnt <= 0;
				pulse_out <= '0';
				if trig = '1' and cnt = 0 then
					cnt <= 1;
					trig_done <= '0';
				elsif cnt = 1 then
					trig_done <= '1';
					cnt <= 0;
				else
					trig_done <= '0';
					cnt <= 0;
				end if;
			end if;
		end if;
end process;



end Behavioral;

