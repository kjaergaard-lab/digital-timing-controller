classdef TimingController < handle
    %TimingController Defines a class to control digital timing controller
    %
    %   The TimingController class can be used to simplify interactions
    %   with the associated digital timing controller.  It allows for
    %   starting/stopping sequences, writing manual values, and uploading
    %   sequences
    properties
        channels        %Array of TimingControllerChannel objects
        ser             %Serial port object
        comPort         %Serial com port
    end
    
    properties(Access = protected)
        compiledData    %Array of compiled data
    end
    
    properties(Constant, Hidden = true)
        ID = 0;                                     %ID of the controller
        NUM_CHANNELS = 32;                          %Number of allowed channels
        SER_PORT_DEFAULT = 'com3';                  %Default serial port of the FPGA
        SER_PORT_BAUDRATE = 115200;                 %Baud rate of the FPGA serial controller
        SER_PORT_BUFFER_SIZE = 2^10;                %Serial port buffer size
        FPGA_SAMPLE_CLK = 25e6;                     %Controller sample clock, in Hz
        
        FPGA_COMMAND_START = 0;                     %Command to start the wait-for-trigger stage
        FPGA_COMMAND_STOP = 1;                      %Command to stop the sequence
        FPGA_COMMAND_READ_STATUS = 2;               %Command to request the controller status
        FPGA_COMMAND_READ_MANUAL = 3;               %Command to read current manual values
        FPGA_COMMAND_WRITE_MANUAL = bitshift(1,16); %Command to write manual values
        FPGA_COMMAND_MEM_UPLOAD = bitshift(2,16);   %Command to upload instructions to memory
        
        FPGA_SEQ_DELAY = 0;                         %Instruction header indicating a wait command
        FPGA_SEQ_OUT = 1;                           %Instruction header indicating a digital-output command
        FPGA_SEQ_IN = 2;                            %Instruction header indicating a digital-input command
        
        FPGA_ADDR_WIDTH = 11;                       %Width of controller address bus - max number of instructions is 2^11
        
    end
    
    
    methods
        function tc = TimingController
            %TimingController Constructs a TimingController object with
            %default values
            %
            %   tc = TimingController constructs a TimingController object
            %   tc
            tmp(tc.NUM_CHANNELS,1) = TimingControllerChannel;
            tc.channels = tmp;
            for nn=1:tc.NUM_CHANNELS
                tc.channels(nn).setParent(tc).setBit(nn-1);
            end
        end
        
        %% Serial port functions
        function open(tc)
            %OPEN Opens a serial port
            %
            %   Uses the TimingController.comPort and 
            %   TimingController.SERIAL_PORT_BAUDRATE properties to
            %   open a serial port.  Checks for already open or existing
            %   interfaces and uses those if they exist.
            %
            %   If the comPort property is empty, uses
            %   TimingController.SER_PORT_DEFAULT as the port
            if isempty(tc.comPort)
                tc.comPort = tc.SER_PORT_DEFAULT;
            end
            if isa(tc.ser,'serial') && isvalid(tc.ser) && strcmpi(tc.ser.port,tc.comPort)
                if strcmpi(tc.ser.status,'closed')
                    fopen(tc.ser);
                end
                return
            else
                r = instrfindall('type','serial','port',upper(tc.comPort));
                if isempty(r)
                    tc.ser=serial(tc.comPort,'baudrate',tc.SER_PORT_BAUDRATE);
                    tc.ser.OutputBufferSize = tc.SER_PORT_BUFFER_SIZE;
                    tc.ser.InputBufferSize = tc.SER_PORT_BUFFER_SIZE;
                    fopen(tc.ser);
                elseif strcmpi(r.status,'open')
                    tc.ser = r;
                else
                    tc.ser = r;
                    tc.ser.OutputBufferSize = tc.SER_PORT_BUFFER_SIZE;
                    tc.ser.InputBufferSize = tc.SER_PORT_BUFFER_SIZE;
                    fopen(tc.ser);
                end   
            end
        end
        
        function close(sv)
            %CLOSE Closes the serial port
            %   Closes and deletes the serial port associated with the
            %   timing controller.
            if isa(sv.ser,'serial') && isvalid(sv.ser) && strcmpi(sv.ser.port,sv.comPort)
                if strcmpi(sv.ser.status,'open')
                    fclose(sv.ser);
                end
                delete(sv.ser);
            end
        end
        
        function delete(sv)
            %DELETE Deletes the timing controller object
            %   DELETE calls the TimingController.close() function to close 
            %   the serial connection
            sv.close;
        end
        
        %%
        function tc = reset(tc)
            %RESET Resets the TimingController channels to their default
            %state
            %
            %   tc = tc.reset resets the TimingController
            for nn=1:tc.NUM_CHANNELS
                tc.channels(nn).reset;
            end
        end
        
        function v = getDefaults(tc)
            %getDefaults Returns the default values stored in each channel
            %
            %   v = tc.getDefaults returns the default value as a uint32
            %   value, which is how the physical controller is programmed
            v = 0;
            for nn=1:tc.NUM_CHANNELS
                v = v+bitshift(tc.channels(nn).default,tc.channels(nn).getBit);
            end
        end
        
        function ch = findBit(tc,bit)
            %findBit Returns the channel corresponding to a given
            %bit-number
            %
            %   ch = tc.findBit(BIT) returns the TimingControllerChannel
            %   with bit-number BIT.  Returns empty if not found
            ch = [];
            for nn=1:tc.NUM_CHANNELS
                if tc.channels(nn).getBit == bit
                    ch = tc.channels(nn);
                    break;
                end
            end
        end
        
        function tc = compile(tc)
            %COMPILE Compiles the channel sequences
            %
            %   tc = tc.compile creates a set of instructions comprising
            %   instruction headers and values from all of the channel
            %   sequences.
            t = [];
            v = [];
            for nn=1:tc.NUM_CHANNELS
                tc.channels(nn).check.sort;
                [t2,v2] = tc.channels(nn).getEvents;
                t = [t;t2];   %#ok
%                 v = [v;bitshift(v2,repmat(tc.channels(nn).getBit,numel(v2),1))];    %#ok
                tmp = [repmat(tc.channels(nn).getBit,numel(v2),1),v2];
                v = [v;tmp];
            end
            [t,k] = sort(round(t*tc.FPGA_SAMPLE_CLK));
            v = v(k,:);
            buf = zeros(size(t,1),2,'uint32');
            buf(1,:) = uint32([t(1),bitshift(v(1,2),v(1,1)+1,'uint32')]);
            numBuf = 1;
            for nn=2:size(t,1)
                if t(nn)==t(nn-1)
%                     buf(numBuf,2) = buf(numBuf,2)+uint32(v(nn));
                    buf(numBuf,2) = bitset(buf(numBuf,2),v(nn,1)+1,v(nn,2),'uint32');
                else
                    numBuf = numBuf + 1;
                    buf(numBuf,:) = uint32([t(nn) bitset(buf(numBuf-1,2),v(nn,1)+1,v(nn,2),'uint32')]);
                end
            end
            
            buf = buf(1:numBuf,:);
            data = zeros(numel(buf),2,'uint32');
            data(1,:) = [tc.FPGA_SEQ_OUT,buf(1,2)];
            numData = 1;
            for nn=2:size(buf,1)
                dt = buf(nn,1)-buf(nn-1,1);
                if dt==1
                    numData = numData+1;
                    data(numData,:) = [tc.FPGA_SEQ_OUT,buf(nn,2)];
                else
                    data(numData+1,:) = [tc.FPGA_SEQ_DELAY,dt];
                    data(numData+2,:) = [tc.FPGA_SEQ_OUT,buf(nn,2)];
                    numData = numData+2;
                end
            end
            data = data(1:numData,:);
            if numData > (2^tc.FPGA_ADDR_WIDTH)
                error('Number of instructions (%d) exceeds maximum number of instructions (%d)',numData,2^tc.FPGA_ADDR_WIDTH);
            end
            tc.compiledData = data;
        end
        
        function tc = upload(tc,dev)
            %UPLOAD Uploads the stored compiled data to the device
            %
            %   tc.upload uplods the stored compiled data to the serial
            %   device.
            %
            %   tc.upload(dev) uploads the stored compiled data to the
            %   given device dev, where dev is compatible with
            %   fwrite(dev,data,dataType) commands.
            if nargin < 2
                tc.open;
                dev = tc.ser;
            end
            fwrite(dev,tc.FPGA_COMMAND_STOP,'uint32');
            fwrite(dev,tc.FPGA_COMMAND_WRITE_MANUAL,'uint32');
            fwrite(dev,tc.getDefaults,'uint32');
            fwrite(dev,tc.FPGA_COMMAND_MEM_UPLOAD+size(tc.compiledData,1)-1,'uint32');   %Note the size - 1
            for nn=1:size(tc.compiledData,1)
                fwrite(dev,uint32(tc.compiledData(nn,2)),'uint32');
                fwrite(dev,uint32(tc.compiledData(nn,1)),'uint8');
            end
            fwrite(dev,tc.FPGA_COMMAND_START,'uint32');
        end
        
        function data = getCompiledData(tc)
            %getCompiledData Returns data compiled by COMPILE
            %
            %   data = tc.getCompiledData returns compiled data
            data = tc.compiledData;
        end
        
        function tc = start(tc,dev)
            %START Issues the start command
            %
            %   tc.start issues the start command over serial
            %   tc.start(DEV) issues the start command to device/file DEV
            if nargin < 2
                tc.open;
                dev = tc.ser;
            end
            fwrite(dev,tc.FPGA_COMMAND_START,'uint32');
        end
        
        function tc = stop(tc,dev)
            %STOP Issues the stop command
            %
            %   tc.stop issues the stop command over serial
            %   tc.stop(DEV) issues the stop command to device/file DEV
            if nargin < 2
                tc.open;
                dev = tc.ser;
            end
            fwrite(dev,tc.FPGA_COMMAND_STOP,'uint32');
        end
        
        function tc = writeDefaults(tc,dev)
            %writeDefaults Writes default values to the device
            %
            %   tc.writeDefaults writes default values using serial
            %   tc.writeDefaults(DEV) writes default values using
            %   device/file DEV
            if nargin < 2
                tc.open;
                dev = tc.ser;
            end
            tc.writeManual(tc.getDefaults,dev);
        end
        
        function tc = writeManual(tc,v,dev)
            %writeManual Writes manual values to the device
            %
            %   tc = tc.writeManual writes the manual values currently
            %   stored in the channel objects to the FPGA over serial
            %
            %   tc = tc.writeManual(v) writes the value given by v to the
            %   FPGA over serial
            %
            %   tc = tc.writeManual(v,dev) writes the value given by v to
            %   the device/file given by dev
            if nargin == 1
                v = 0;
                for nn = 1:tc.NUM_CHANNELS
                    v = v+bitshift(tc.channels(nn).manual,tc.channels(nn).getBit);
                end
                tc.open;
                dev = tc.ser;
            elseif nargin == 2
                tc.open;
                dev = tc.ser;
            end
            fwrite(dev,tc.FPGA_COMMAND_WRITE_MANUAL,'uint32');
            fwrite(dev,uint32(v),'uint32');
        end
        
        function r = readManual(tc)
            %readManual Reads the current manual values from the FPGA
            %
            %   r = tc.readManual reads the current manual values from the
            %   FPGA over serial
            tc.open;
            fwrite(tc.ser,tc.FPGA_COMMAND_READ_MANUAL,'uint32');
            while tc.ser.BytesAvailable~=4
                pause(10e-3);
            end
            r = fread(tc.ser,1,'uint32');
        end
        
        function status = readStatus(tc)
            %readStatus Reads the status of the timing controller
            %
            %   STATUS = tc.readStatus returns a structure STATUS with
            %   fields 'seqEnabled', 'seqRunning', and 'addr'.  
            tc.open;
            fwrite(tc.ser,tc.FPGA_COMMAND_READ_STATUS,'uint32');
            while tc.ser.BytesAvailable~=4
                pause(10e-3);
            end
            r = fread(tc.ser,1,'uint32');
            status.seqEnabled = bitget(r,32);
            status.seqRunning = bitget(r,31);
            status.addr = bitand(r,bitcmp(bitshift(3,30),'uint32'));
        end
        
        function tc = plot(tc,offset)
            %PLOT Plots all channel sequences
            %
            %   tc = tc.plot plots all channel sequences on the same graph
            %
            %   tc = tc.plot(offset) plots all channel sequences on the
            %   same graph but with each channel's sequence offset from the
            %   next by offset
            jj = 1;
            if nargin < 2
                offset = 0;
            end
            for nn = 1:tc.NUM_CHANNELS
                tc.channels(nn).plot((jj-1)*offset);
                hold on;
                if tc.channels(nn).getNumValues > 0
                    str{jj} = sprintf('Ch %d',tc.channels(nn).getBit);  %#ok<AGROW>
                end
            end
            hold off;
            legend(str);
            xlabel('Time [s]');
        end
        
        function [t,v] = plotCompiledData(tc,offset)
            %plotCompiledData Plots compiled data as time/value pairs.
            %
            %   [t,v] = tc.plotCompiledData plots compiled data as
            %   time/value pairs and returns those values in variables t
            %   and v.  Unlike TimingController.plot, this plots ALL
            %   channels
            %
            %   [t,v] = tc.plotCompiledData(offset) plots all channel 
            %   sequences on the same graph but with each channel's 
            %   sequence offset from the next by offset
            if nargin < 2
                offset = 0;
            end
            t = 0;
            v = bitget(tc.compiledData(1,2),1:32,'uint32');
            jj = 2;
            for nn=2:size(tc.compiledData,1)
                if tc.compiledData(nn,1)==tc.FPGA_SEQ_DELAY
                    t(jj,1) = t(jj-1)+double(tc.compiledData(nn,2))/tc.FPGA_SAMPLE_CLK;
                    v(jj,:) = v(jj-1,:);
                    jj = jj+1;
                elseif tc.compiledData(nn,1)==tc.FPGA_SEQ_OUT
                    t(jj) = t(jj-1);
                    v(jj,:) = bitget(tc.compiledData(nn,2),1:32,'uint32');
                    jj = jj+1;
                end
            end
            
            for nn=1:tc.NUM_CHANNELS
                str{nn} = sprintf('%d',tc.channels(nn).getBit);
                plot(t,double(v(:,nn))+(nn-1)*offset,'.-','linewidth',1.5);
                hold on;
            end
            legend(str);
        end
        
    end
    
    
end