classdef SpartanImagingController < TimingController
    properties
        %% Normal imaging channels
        probeRb
        shutterRb
        probeK
        shutterK
        camTrig
        
        %% Vertical imaging channels
        camTrigV
        probeV
        shutterV
        levitationCoil
        
        %% Fluorescence imaging
        probeF
        shutterF
        
        %% Laser control
        laser
        
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
            sp.probeRb = sp.findBit(0);
            sp.shutterRb = sp.findBit(1);
            sp.probeK = sp.findBit(2);
            sp.shutterK = sp.findBit(3);
            sp.camTrig = sp.findBit(4);
            
            %% Vertical imaging channels
            sp.camTrigV = sp.findBit(5);
            sp.probeV = sp.findBit(6);
            sp.shutterV = sp.findBit(7);
            sp.levitationCoil = sp.findBit(8);
            
            %% Laser control
            sp.laser = sp.findBit(9);
            
            %% State preparation
            sp.mw = sp.findBit(10);
            sp.rf = sp.findBit(11);
            sp.pulseType = sp.findBit(12);
            
        end
    
    end
    
end