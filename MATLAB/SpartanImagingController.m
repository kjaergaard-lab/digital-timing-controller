classdef SpartanImagingController < TimingController
    properties
        %% Normal imaging channels
        camTrig
        probeRb
        shutterRb
        probeK
        shutterK
        
        %% Vertical imaging channels
        probeV
        shutterV
        camTrigV
        
        %% Fluorescence imaging
        probeRepumpF
        probeMOTF
        shutterRepumpF
        shutterMOTF
        
        %% Laser control
        laser
        
        %% Coil control
        coil
        
        %% State preparation
        mw
        rf
        pulseType

    end
    
    methods
        function sp = SpartanImagingController
            sp = sp@TimingController;
            sp.defineChannels;
        end
        
        function sp = defineChannels(sp)
            %% Normal imaging channels
            sp.camTrig = sp.findBit(0);
            sp.probeRb = sp.findBit(1);
            sp.shutterRb = sp.findBit(2);
            sp.probeK = sp.findBit(3);
            sp.shutterK = sp.findBit(4);
            
            
            %% Vertical imaging channels
            sp.probeV = sp.findBit(5);
            sp.shutterV = sp.findBit(6);
            sp.camTrigV = sp.findBit(7);
            
            %% Fluorescence imaging channels
            sp.probeRepumpF = sp.findBit(8);
            sp.probeMOTF = sp.findBit(9);
            sp.shutterRepumpF = sp.findBit(10);
            sp.shutterMOTF = sp.findBit(11);
            
            %% Laser control
            sp.laser = sp.findBit(12);
            
            %% Coil control
            sp.coil = sp.findBit(13);
            
            %% State preparation
            sp.mw = sp.findBit(14);
            sp.rf = sp.findBit(15);
            sp.pulseType = sp.findBit(16);
            
        end
        
        function sp = plot(sp,offset)
            if nargin < 2
                offset = 0;
            end
            jj = 1;
            p = properties(sp);
            for nn = 1:numel(p)
                ch = sp.(p{nn});
                if ~isa(ch,'TimingControllerChannel') || numel(ch)>1
                    continue;
                end
                ch.plot((jj-1)*offset);
                hold on;
                if ch.getNumValues > 0
                    str{jj} = sprintf('%s (%d)',p{nn},ch.getBit);  %#ok<AGROW>
                    jj = jj+1;
                end
            end
            hold off;
            legend(str);
        end
    
    end
    
end