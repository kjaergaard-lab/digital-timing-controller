classdef SpartanImaging < handle
    properties(Access = public)
        %Public properties that are settable by the user
        fileBase='C:\Users\nkgroup.PX\Documents\FPGA Files\FPGA';
        
        %Imaging properties
        probeType
        imageDelay
        enableVerticalImaging
        enableCoil
        
        crossbeamOnTime
        timeOfFlight
        additionalWaveguideOnTime
        probeWidthRb
        probeWidthK
        probeWidthVertical
        probeWidthF
        
        probeShutterDelay
        camDelay
        camLoopTime
        repumpProbeWidth
        repumpProbeDelay
        repumpShutterDelay
        
        enableProbe
        enableRepump
        
        %State prep parameters
        numPulses
        pulses
        
        %FlexDDS parameters
        flexDDS1
        flexDDS2
        flexDDS3
        
    end
    
    properties(Access = protected)
        %Protected properties that are calculated by the class
       	numConfigs
        
        waveguideOnTime
        probeSeqDelayTime
        probeSeqDelayTimeVertical
        coilOnTime
        coilOffTime
        pulseDelays
        enableLight
    end
    
    properties(Constant, Hidden=true)
        %Constant values for the class
        comPort='com3';
        %These are hard-coded into the VHDL code
        clk=50e6;
        singleImageDelay=6.5*0;           %in ms
        doubleImageDelay=30+8-0.015;    %in ms
        verticalImageDelay=10;          %in ms
        coilDelay=2;    %in ms
        
        minCycleTime=5; %in clock edges
        
        controller = SpartanImagingController;
    end
    
    
    methods
        function sp = SpartanImaging
            sp.resetValues;
        end
        
        function sp = resetValues(sp)
            sp.probeType = 'Rb';
            sp.imageDelay = 160e-6;
            sp.enableVerticalImaging = 0;
            sp.enableCoil = 0;
            
        end
        
        function sp = makeRbSeq(sp)
            switch upper(sp.probeType)
                case 'RB'
                    onTime = sp.crossbeamOnTime+sp.timeOfFlight;
                    offTime = onTime+sp.probeWidthRb;
                    sp.controller.probeRb.add(onTime,1,'ms').add(offTime,0,'ms');
                    sp.controller.shutterRb.add(onTime-sp.probeShutterDelay,1,'ms').add(offTime,0,'ms');
                    sp.controller.camTrig.add(onTime-sp.camDelay,1,'ms').add(offTime,0,'ms');
                
                    
                
            end
            
        end
        
        
        
    end
    
    
    
end