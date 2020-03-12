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
        
        %% Aux properties
        lastTime
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
        
        function [t,v] = getEvents(ch)
            ch.check;
            ch.sort;
            if ch.numValues==0
                t = 0;
                v = ch.default;
            elseif ch.times(1) == 0
                t = ch.times;
                v = ch.values;
            else
                t = [0;ch.times];
                v = [ch.default;ch.values];
            end
        end
        
        function N = getNumValues(ch)
            N = ch.numValues;
        end
        
        function ch = on(ch,time,value,timeUnit)
            if nargin==4 && isnumeric(timeUnit)
                time = time*timeUnit;
            elseif nargin==4 && ischar(timeUnit)
                time = time*ch.getTimeUnit(timeUnit);
            end
            time = round(time*TimingController.FPGA_SAMPLE_CLK)/TimingController.FPGA_SAMPLE_CLK;
            
            idx = find(ch.times==time,1,'first');
            if value~=0 && value~=1
                error('Value must be either 0 or 1');
            end
            
            if isempty(idx)
                N = ch.numValues+1;
                ch.values(N,1) = value;
                ch.times(N,1) = time;
                ch.numValues = N;
                ch.lastTime = time;
            else
%                 warning('Value %d at time %.3g is being replaced',ch.values(idx),ch.times(idx));
                ch.values(idx,1) = value;
                ch.times(idx,1) = time;
                ch.lastTime = time;
            end
        end
        
        function ch = after(ch,delay,value,timeUnit)
            if nargin==4 && isnumeric(timeUnit)
                delay = delay*timeUnit;
            elseif nargin==4 && ischar(timeUnit)
                delay = delay*ch.getTimeUnit(timeUnit);
            end
            
            time = ch.lastTime+delay;
            ch.on(time,value);
        end
        
        function ch = before(ch,delay,value,timeUnit)
            if nargin==4 && isnumeric(timeUnit)
                delay = delay*timeUnit;
            elseif nargin==4 && ischar(timeUnit)
                delay = delay*ch.getTimeUnit(timeUnit);
            end
            
            time = ch.lastTime-delay;
            ch.on(time,value);
        end
        
        function ch = anchor(ch,time,timeUnit)
            if nargin==3 && isnumeric(timeUnit)
                time = time*timeUnit;
            elseif nargin==3 && ischar(timeUnit)
                time = time*ch.getTimeUnit(timeUnit);
            end
            
            ch.lastTime = round(time*TimingController.FPGA_SAMPLE_CLK)/TimingController.FPGA_SAMPLE_CLK;
        end
        
        function [time,value] = last(ch)
            time = ch.times(end);
            value = ch.values(end);
        end
        
        function ch = reset(ch)
            ch.times = [];
            ch.values = [];
            ch.numValues = 0;
            ch.lastTime = [];
        end
        
        function ch = sort(ch)
            [B,K] = sort(ch.times);
            ch.times = B;
            ch.values = ch.values(K);
        end
        
        function ch = check(ch)
            if any(ch.times<0)
                error('All times must be greater than 0 (no acausal events)!');
            end
        end
        
        function ch = plot(ch,offset)
            [t,v] = ch.getEvents;
            tplot = sort([t;t-1/ch.parent.FPGA_SAMPLE_CLK]);
            if numel(v)==1
                fprintf(1,'No events on this channel (%d). Plot not generated.\n',ch.bit);
                return
            end
            vplot = interp1(t,v,tplot,'previous');
            if nargin==2
                vplot = vplot+offset;
            end
            plot(tplot,vplot,'.-','linewidth',1.5);
        end
        
    end
    
    methods(Static)
        function scale = getTimeUnit(unit)
            switch lower(unit)
                case 'ns'
                    scale = 1e-9;
                case 'us'
                    scale = 1e-6;
                case 'ms'
                    scale = 1e-3;
                case 's'
                    scale = 1;
                otherwise
                    error('Unit unknown');
            end
        end
    end
    
    
end