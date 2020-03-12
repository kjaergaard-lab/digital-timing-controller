classdef SpartanFlexDDSTriggerSystem < handle
    properties
        numTriggers     %Number of triggers
        trigFreq        %Trigger frequency [Hz]
    end
    
    properties(Constant)
        ID = 1;
        SET_NUM_PULSE = 0;
        SET_PULSE_FREQ = 1;
        NUM_OUTPUTS = 3;
        CLK = 100e6;
    end
    
    methods
        function dds = SpartanFlexDDSTriggerSystem
            dds.trigFreq = 200e3*ones(dds.NUM_OUTPUTS,1);
            dds.numTriggers = 10*dds.trigFreq;
        end
        
        function dds = upload(dds,dev)
            for nn=1:dds.NUM_OUTPUTS
                fwrite(dev,bitshift(nn,8)+dds.SET_NUM_PULSE,'uint32');
                fwrite(dev,dds.numTriggers(nn),'uint32');
                fwrite(dev,bitshift(nn,8)+dds.SET_PULSE_FREQ,'uint32');
                dwrite(dev,round(dds.CLK/dds.trigFreq(nn)),'uint32');
            end
        end
        
    end
    
    
    
end