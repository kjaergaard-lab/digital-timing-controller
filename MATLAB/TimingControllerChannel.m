classdef TimingControllerChannel < handle
    properties
        %% Static properties
        default
        manual
        
    end
    
    properties(Access = protected)
        bit
        parent
        
        %% Sequence properties
        values
        times
        numValues
    end
    
    methods
        function ch = TimingControllerChannel(parent,bit)
            if nargin >= 1
                ch.parent = parent;
            end
            if nargin >= 2
                ch.bit = bit;
            end
            ch.default = 0;
            ch.reset;
        end
        
        function ch = setParent(ch,parent)
            ch.parent = parent;
        end
        
        function p = getParent(ch)
            p = ch.parent;
        end
        
        function ch = setBit(ch,bit)
            if bit>=0 && bit<ch.parent.NUM_CHANNELS
                ch.bit = bit;
            end
        end
        
        function b = getBit(ch)
            b = ch.bit;
        end
        
        function v = getEvents(ch)
            v = [ch.getTimes ch.getValues];
        end
        
        function v = getValues(ch)
            v = [ch.default;ch.values];
        end
        
        function t = getTimes(ch)
            t = [0;ch.times];
        end
        
        function N = getNumValues(ch)
            N = ch.numValues;
        end
        
        function ch = add(ch,time,value)
            if value~=0 && value~=1
                error('Value must be either 0 or 1');
            end
            time = round(time*TimingController.FPGA_SAMPLE_CLK)/TimingController.FPGA_SAMPLE_CLK;
            idx = find(ch.times==time,1,'first');
            if isempty(idx)
                N = ch.numValues+1;
                ch.values(N,1) = value;
                ch.times(N,1) = time;
                ch.numValues = N;
            else
                warning('Value %d at time %.3g is being replaced',ch.values(idx),ch.times(idx));
                ch.values(idx,1) = value;
                ch.times(idx,1) = time;
            end
        end
        
        function ch = reset(ch)
            ch.times = [];
            ch.values = [];
            ch.numValues = 0;
        end
        
        function ch = sort(ch)
            [B,K] = sort(ch.times);
            ch.times = B;
            ch.values = ch.values(K);
        end
        
        function ch = plot(ch)
            [t,K] = sort(ch.times);
            t = [0;t];
            v = [ch.default;ch.values(K)];
%             tplot = 0:1/ch.parent.FPGA_SAMPLE_CLK:max(t);
%             vplot = interp1(t,v,tplot,'previous');
            tplot = sort([t;t-1/ch.parent.FPGA_SAMPLE_CLK]);
            vplot = interp1(t,v,tplot,'previous');
            plot(tplot,vplot,'.-');
        end
        
    end
    
    
end