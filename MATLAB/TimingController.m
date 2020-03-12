classdef TimingController < handle
    properties
        %% Channel properties
        channels
        
        %% Serial port properties
        ser         %serial object
        comPort     %Serial com port
        
        compiledData
    end
    
    properties(Constant, Hidden = true)
        ID = 0;
        NUM_CHANNELS = 32;
        SER_PORT_DEFAULT = 'com3';
        SER_PORT_BAUDRATE = 115200;
        SER_PORT_BUFFER_SIZE = 2^10;
        FPGA_SAMPLE_CLK = 20e6;            %In Hz
        
        FPGA_COMMAND_STOP = 0;
        FPGA_COMMAND_START = 1;
        FPGA_COMMAND_READ_STATUS = 2;
        FPGA_COMMAND_READ_MANUAL = 3;
        FPGA_COMMAND_WRITE_MANUAL = bitshift(1,16);
        FPGA_COMMAND_MEM_UPLOAD = bitshift(2,16);
        
        FPGA_SEQ_DELAY = 0;
        FPGA_SEQ_OUT = 1;
        FPGA_SEQ_IN = 2;
        
        FPGA_ADDR_WIDTH = 11;
        
    end
    
    
    methods
        function tc = TimingController
            tmp(tc.NUM_CHANNELS,1) = TimingControllerChannel;
            tc.channels = tmp;
            for nn=1:tc.NUM_CHANNELS
                tc.channels(nn).setParent(tc).setBit(nn-1);
            end
        end
        
        %% Serial port functions
        function open(tc)
            %OPEN Opens a serial port
            %   Uses the servo.comPort and servo.BAUD_RATE properties to
            %   open a serial port.  Checks for already open or existing
            %   interfaces and uses those if they exist.
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
            %   servo controller.
            if isa(sv.ser,'serial') && isvalid(sv.ser) && strcmpi(sv.ser.port,sv.comPort)
                if strcmpi(sv.ser.status,'open')
                    fclose(sv.ser);
                end
                delete(sv.ser);
            end
        end
        
        %%
        function tc = reset(tc)
            for nn=1:tc.NUM_CHANNELS
                tc.channels(nn).reset;
            end
        end
        
        function v = getDefaults(tc)
            v = 0;
            for nn=1:tc.NUM_CHANNELS
                v = v+bitshift(tc.channels(nn).default,tc.channels(nn).getBit);
            end
        end
        
        function ch = findBit(tc,bit)
            ch = [];
            for nn=1:tc.NUM_CHANNELS
                if tc.channels(nn).getBit == bit
                    ch = tc.channels(nn);
                    break;
                end
            end
        end
        
        function data = compile(tc)
            t = [];
            v = [];
            for nn=1:tc.NUM_CHANNELS
                tc.channels(nn).check.sort;
                t = [t;tc.channels(nn).getTimes];   %#ok
                v = [v;bitshift(tc.channels(nn).getValues,repmat(tc.channels(nn).getBit,tc.channels(nn).getNumValues+1,1))];    %#ok
            end
            [t,k] = sort(round(t*tc.FPGA_SAMPLE_CLK));
            v = v(k);
            buf = zeros(size(t,1),2,'uint32');
            buf(1,:) = uint32([t(1),v(1)]);
            numBuf = 1;
            for nn=2:size(t,1)
                if t(nn)==t(nn-1)
                    buf(numBuf,2) = buf(numBuf,2)+uint32(v(nn));
                else
                    numBuf = numBuf + 1;
                    buf(numBuf,:) = uint32([t(nn) v(nn)]);
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
            if nargin < 2
                tc.open;
                dev = tc.ser;
            end
            fwrite(dev,tc.FPGA_COMMAND_STOP,'uint32');
            fwrite(dev,tc.FPGA_COMMAND_WRITE_MANUAL,'uint32');
            fwrite(dev,tc.getDefaults,'uint32');
            fwrite(dev,tc.FPGA_COMMAND_MEM_UPLOAD+size(tc.compiledData,1)-1,'uint32');   %Note the size - 1
            for nn=1:size(tc.compiledData,1)
                fwrite(dev,uint32(tc.compiledData(nn,1)),'uint8');
                fwrite(dev,uint32(tc.compiledData(nn,2)),'uint32');
            end
            fwrite(dev,tc.FPGA_COMMAND_START,'uint32');
        end
        
        function tc = start(tc)
            tc.open;
            fwrite(tc.ser,tc.FPGA_COMMAND_START,'uint32');
        end
        
        function tc = stop(tc)
            tc.open;
            fwrite(tc.ser,tc.FPGA_COMMAND_STOP,'uint32');
        end
        
        function tc = writeDefaults(tc)
            tc.open;
            fwrite(tc.ser,tc.FPGA_COMMAND_WRITE_MANUAL,'uint32');
            fwrite(tc.ser,tc.getDefaults,'uint32');
        end
        
    end
    
    
end