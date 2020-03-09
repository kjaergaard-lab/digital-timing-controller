classdef TimingController < handle
    properties
        %% Channel properties
        channels
        
        %%
        ser         %serial object
        compiledData
    end
    
    properties(Constant)
        NUM_CHANNELS = 32;
        SER_PORT_DEFAULT = 'com3';
        SER_PORT_BAUDRATE = 115200;
        FPGA_SAMPLE_CLK = 20e6;            %In Hz
        
        FPGA_COMMAND_STOP = 0;
        FPGA_COMMAND_START = 1;
        FPGA_COMMAND_UPLOAD = 2;
        FPGA_COMMAND_WRITE_DEFAULTS = 3;
        
        FPGA_SEQ_UPDATE = 0;
        FPGA_SEQ_DELAY = 1;
    end
    
    
    methods
        function tc = TimingController
            tmp(tc.NUM_CHANNELS,1) = TimingControllerChannel;
            tc.channels = tmp;
            for nn=1:tc.NUM_CHANNELS
                tc.channels(nn).setParent(tc).setBit(nn-1);
            end
        end
        
        function tc = open(tc)
            
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
                tc.channels(nn).sort;
                t = [t;tc.channels(nn).getTimes];
                v = [v;bitshift(tc.channels(nn).getValues,repmat(tc.channels(nn).getBit,tc.channels(nn).getNumValues+1,1))];
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
            data(1,:) = [tc.FPGA_SEQ_UPDATE,buf(1,2)];
            numData = 1;
            for nn=2:size(buf,1)
                dt = buf(nn,1)-buf(nn-1,1);
                if dt==1
                    numData = numData+1;
                    data(numData,:) = [tc.FPGA_SEQ_UPDATE,buf(nn,2)];
                else
                    data(numData+1,:) = [tc.FPGA_SEQ_DELAY,dt];
                    data(numData+2,:) = [tc.FPGA_SEQ_UPDATE,buf(nn,2)];
                    numData = numData+2;
                end
            end
            data = data(1:numData,:);
            tc.compiledData = data;
        end
        
        function tc = upload(tc)
            tc.open;
            fwrite(tc.ser,tc.FPGA_COMMAND_STOP,'uint32');
            fwrite(tc.ser,tc.FPGA_COMMAND_WRITE_DEFAULTS,'uint32');
            fwrite(tc.ser,tc.getDefaults,'uint32');
            
        end
    end
    
    
end