classdef SpartanImaging < handle
    properties(Access = public)
        %Public properties that are settable by the user
        fileBase='C:\Users\nkgroup.PX\Documents\FPGA Files\FPGA';
        
        %Imaging properties
        probeType
        imageDelay
        enableCoil
        
        crossbeamOnTime
        timeOfFlight
        additionalWaveguideOnTime
        probeWidthRb
        probeWidthK
        probeWidthV
        probeWidthF
        
        probeShutterDelay
        camExp
        camLoopTime
        repumpProbeWidth
        repumpProbeDelay
        repumpShutterDelay
        
        enableProbe
        enableRepump
        
        %State prep parameters
        numPulses
        pulses
        
    end
    
    properties(Access = protected)
        %Protected properties that are calculated by the class
       	numConfigs
    end
    
    properties(Constant)
        controller = SpartanImagingController;
        flexDDSTriggers = SpartanFlexDDSTriggerSystem;
    end
    
    properties(Constant, Hidden=true)
        %Constant values for the class
        SER_COM_PORT = 'com3';
        
        ANDOR_FIRST_LOOP_TIME = 30;     %[ms]
        ANDOR_READ_TIME = 20;           %[ms]
    end
    
    
    methods
        function sp = SpartanImaging
            sp.resetValues;
        end
        
        function sp = resetValues(sp)
            sp.probeType = 'Rb';
            sp.imageDelay = 0.16;
            sp.enableCoil = 0;
            
            sp.crossbeamOnTime = 50;
            sp.timeOfFlight = 20;
            sp.additionalWaveguideOnTime = 0;
            sp.probeWidthRb = 15;
            sp.probeWidthK = 15;
            sp.probeWidthF = 15;
            sp.probeWidthV = 15;
            
            sp.repumpProbeDelay = 0.15;
            sp.repumpProbeWidth = 150;
            sp.repumpShutterDelay = 2.5;
            
            sp.camExp = 0.25;
            sp.camLoopTime = 30;
            sp.probeShutterDelay = 2.5;
            
            sp.enableProbe = 1;
            sp.enableRepump = 1;
            
            sp.controller.comPort = sp.SER_COM_PORT;
            
        end
        
        function sp = makeSingleImageSeq(sp)
            switch upper(sp.probeType)
                case 'RB'
                    width = sp.probeWidthRb;
                    probe = sp.controller.probeRb;
                    shutter = sp.controller.shutterRb;
                    camTrig = sp.controller.camTrig;
                case 'K'
                    width = sp.probeWidthK;
                    probe = sp.controller.probeK;
                    shutter = sp.controller.shutterK;
                    camTrig = sp.controller.camTrig;
                case 'F'
                    width = sp.probeWidthF;
                    probe = sp.controller.probeMOTF;
                    shutter = sp.controller.shutterMOTF;
                    camTrig = sp.controller.camTrig;
                case 'V'
                    width = sp.probeWidthV;
                    probe = sp.controller.probeV;
                    shutter = sp.controller.shutterV;
                    camTrig = sp.controller.camTrigV;
                otherwise
                    error('Single imaging case not supported')
            end
            
            onTime = sp.crossbeamOnTime+sp.timeOfFlight;
            probeR = sp.controller.probeRepumpF;
            shutterR = sp.controller.shutterRepumpF;
            %% First image with atoms
            probe.on(onTime,sp.enableProbe,'ms').after(width,0,'us');
            shutter.on(onTime,sp.enableProbe,'ms').before(sp.probeShutterDelay,sp.enableProbe,'ms').sort.on(probe.last,0);
            camTrig.on(onTime,1,'ms').before(sp.camExp,1,'ms').sort.on(probe.last,0);
            
            probeR.on(onTime-sp.repumpProbeDelay,sp.enableRepump,'ms').after(sp.repumpProbeWidth,0,'us');
            shutterR.on(onTime-sp.repumpProbeDelay-sp.repumpShutterDelay,sp.enableRepump,'ms').on(probeR.last,0);
            
            %% Second image with atoms
            onTime = onTime+sp.camLoopTime;
            probe.on(onTime,sp.enableProbe,'ms').after(width,0,'us');
            shutter.on(onTime,sp.enableProbe,'ms').before(sp.probeShutterDelay,sp.enableProbe,'ms').sort.on(probe.last,0);
            camTrig.on(onTime,1,'ms').before(sp.camExp,1,'ms').sort.on(probe.last,0);
            
            probeR.on(onTime-sp.repumpProbeDelay,sp.enableRepump,'ms').after(sp.repumpProbeWidth,0,'us');
            shutterR.on(onTime-sp.repumpProbeDelay-sp.repumpShutterDelay,sp.enableRepump,'ms').on(probeR.last,0);
            
            %% Third image without atoms
            onTime = onTime+sp.camLoopTime;
            camTrig.on(onTime,1,'ms').before(sp.camExp,1,'ms').sort.after(width,0,'us');
            
        end
        
        function sp = makeDoubleImageSeq(sp)
            switch upper(sp.probeType)
                case 'RBRB'
                    width1 = sp.probeWidthRb;
                    width2 = sp.probeWidthRb;
                    probe1 = sp.controller.probeRb;
                    probe2 = sp.controller.probeRb;
                    shutter1 = sp.controller.shutterRb;
                    shutter2 = sp.controller.shutterRb;
                case 'RBK'
                    width1 = sp.probeWidthRb;
                    width2 = sp.probeWidthK;
                    probe1 = sp.controller.probeRb;
                    probe2 = sp.controller.probeK;
                    shutter1 = sp.controller.shutterRb;
                    shutter2 = sp.controller.shutterK;
                case 'KRB'
                    width1 = sp.probeWidthK;
                    width2 = sp.probeWidthRb;
                    probe1 = sp.controller.probeK;
                    probe2 = sp.controller.probeRb;
                    shutter1 = sp.controller.shutterK;
                    shutter2 = sp.controller.shutterRb;
                case 'KK'
                    width1 = sp.probeWidthK;
                    width2 = sp.probeWidthK;
                    probe1 = sp.controller.probeK;
                    probe2 = sp.controller.probeK;
                    shutter1 = sp.controller.shutterK;
                    shutter2 = sp.controller.shutterK;
                otherwise
                    error('Double imaging case not supported')
            end
            
            camTrig = sp.controller.camTrig;
            onTime = sp.crossbeamOnTime+sp.timeOfFlight;
            delay = max(sp.imageDelay,sp.ANDOR_READ_TIME);
            
            probeR = sp.controller.probeRepumpF;
            shutterR = sp.controller.shutterRepumpF;
            %% Zeroeth, throw-away image for Andor iXon camera in frame-transfer mode
            camTrig.anchor(onTime,'ms').before(sp.ANDOR_FIRST_LOOP_TIME,1,'ms').after(sp.camExp,0,'ms');
            
            %% First images with atoms
            shutter1.anchor(onTime,'ms').before(sp.probeShutterDelay,sp.enableProbe,'ms').sort;
            shutter2.anchor(onTime,'ms').before(sp.probeShutterDelay,sp.enableProbe,'ms').sort;
            
            probe1.on(onTime,sp.enableProbe,'ms').after(width1,0,'us');
            camTrig.on(probe1.last,0).before(sp.camExp,1,'ms');
            
            probe2.anchor(probe1.last).after(sp.imageDelay,sp.enableProbe,'ms').after(width2,0,'us');
            shutter1.on(probe2.last,0);
            shutter2.on(probe2.last,0);
            
            camTrig.after(delay,1,'ms').after(sp.camExp,0,'ms');
            
            probeR.anchor(onTime,'ms').before(sp.repumpProbeDelay,sp.enableRepump,'ms');
            shutterR.anchor(probeR.last).before(sp.repumpShutterDelay,sp.enableRepump,'ms');
            probeR.after(sp.repumpProbeWidth,0,'us');
            shutterR.on(probeR.last,0);
            
            %% Second images without atoms
            onTime = onTime+delay+sp.camLoopTime;
            shutter1.anchor(onTime,'ms').before(sp.probeShutterDelay,sp.enableProbe,'ms').sort;
            shutter2.anchor(onTime,'ms').before(sp.probeShutterDelay,sp.enableProbe,'ms').sort;
            probe1.on(onTime,sp.enableProbe,'ms').after(width1,0,'us');
            camTrig.on(probe1.last,0).before(sp.camExp,1,'ms');
            
            probe2.anchor(probe1.last).after(sp.imageDelay,sp.enableProbe,'ms').after(width2,0,'us');
            shutter1.on(probe2.last,0);
            shutter2.on(probe2.last,0);
            camTrig.after(delay,1,'ms').after(sp.camExp,0,'ms');
            
            probeR.anchor(onTime,'ms').before(sp.repumpProbeDelay,sp.enableRepump,'ms');
            shutterR.anchor(probeR.last).before(sp.repumpShutterDelay,sp.enableRepump,'ms');
            probeR.after(sp.repumpProbeWidth,0,'us');
            shutterR.on(probeR.last,0);
            
            %% Third dark images
            onTime = onTime+delay+sp.camLoopTime;
            camTrig.on(onTime,0,'ms').before(sp.camExp,1,'ms');
            camTrig.after(delay,1,'ms').after(sp.camExp,0,'ms');
            
        end
        
        
        function sp = makeSequence(sp)
            sp.controller.laser.add(0,1).after(sp.crossbeamOnTime+sp.additionalWaveguideOnTime,0,'ms');
            switch upper(sp.probeType)
                case {'RB','K','V','F'}
                    sp.makeSingleImageSeq;
                case {'RBRB','KK','RBK','KRB'}
                    sp.makeDoubleImageSeq;
                otherwise
                    error('Probe type %s not supported!',sp.probeType);
            end
            
        end
        
        function sp = upload(sp)
            sp.controller.upload;
            sp.flexDDSTriggers.upload(sp.controller.ser);
            sp.controller.start;
        end
        
        
        
    end
    
    
    
end