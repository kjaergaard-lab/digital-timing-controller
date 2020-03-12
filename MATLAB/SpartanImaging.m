classdef SpartanImaging < handle
    properties(Access = public)
        %Public properties that are settable by the user
        file
        
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
        
    end
    
    properties(Access = protected)
        %Protected properties that are calculated by the class
       	numConfigs
    end
    
    properties(Constant)
        controller = SpartanImagingController;
        flexDDSTriggers = SpartanFlexDDSTriggerSystem;
        pulses = StatePrepPulses;
    end
    
    properties(Constant, Hidden=true)
        %Constant values for the class
        SER_COM_PORT = 'com3';
        
        ANDOR_FIRST_LOOP_TIME = 30;     %[ms]
        ANDOR_READ_TIME = 20;           %[ms]
        
        EX_PROP = {'file','controller','flexDDSTriggers'};
    end
    
    
    methods
        function sp = SpartanImaging
            sp.reset;
%             sp.file.dir = 'C:\Users\nkgroup.PX\Documents\FPGA Files\';
            sp.file.dir = 'FPGA Files\';
            sp.file.base = 'FPGA';
        end
        
        function sp = reset(sp)
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
            
            sp.controller.reset;
            sp.flexDDSTriggers.reset;
            sp.pulses.reset;
            
            sp.controller.comPort = sp.SER_COM_PORT;
        end
        
        function sp = expandVariables(sp)
            %expandVariables Replicates public variables such that each
            %variable is the same length.  This frees the user from making
            %sure that each variable is the same length
            maxVarLength = 1;
            p = properties(sp);
            for nn = 1:length(p)
                if ~sp.checkProp(p{nn})
                    continue;
                end
                
                v = sp.(p{nn});
                if isnumeric(v) || islogical(v) || iscell(v)
                    N = numel(v);
                elseif isa(v,'StatePrepPulses')
                    N = v.getMaxVarLength;
                else
                    N = 1;
                end
                if N>maxVarLength
                    maxVarLength = N;
                end
            end
            
            for nn = 1:length(p)
                if ~sp.checkProp(p{nn})
                    continue;
                end
                
                v = sp.(p{nn});
                if isnumeric(v) || islogical(v) || iscell(v)
                    N = numel(v);
                    sp.(p{nn}) = [v(:)' repmat(v(end),1,maxVarLength-N)];
                elseif isa(v,'StatePrepPulses')
                    v.repVars(maxVarLength);
                elseif ischar(v)
                    sp.(p{nn}) = repmat({v},1,maxVarLength);
                end
            end
            
            sp.numConfigs = maxVarLength;
        end %end expandVariables
        
        function r = checkProp(sp,p)
            for nn = 1:numel(sp.EX_PROP)
                if strcmpi(sp.EX_PROP(nn),p)
                    r = false;
                    return;
                end
            end
            r = true;     
        end
        
        function sp = makeSingleImageSeq(sp,idx)
            if nargin < 2
                idx = 1;
            end
            if iscell(sp.probeType)
                pt = sp.probeType{idx};
            else
                pt = sp.probeType;
            end
            switch upper(pt)
                case 'RB'
                    width = sp.probeWidthRb(idx);
                    probe = sp.controller.probeRb;
                    shutter = sp.controller.shutterRb;
                    camTrig = sp.controller.camTrig;
                case 'K'
                    width = sp.probeWidthK(idx);
                    probe = sp.controller.probeK;
                    shutter = sp.controller.shutterK;
                    camTrig = sp.controller.camTrig;
                case 'F'
                    width = sp.probeWidthF(idx);
                    probe = sp.controller.probeMOTF;
                    shutter = sp.controller.shutterMOTF;
                    camTrig = sp.controller.camTrig;
                case 'V'
                    width = sp.probeWidthV(idx);
                    probe = sp.controller.probeV;
                    shutter = sp.controller.shutterV;
                    camTrig = sp.controller.camTrigV;
                otherwise
                    error('Single imaging case not supported')
            end
            
            onTime = sp.crossbeamOnTime(idx)+sp.timeOfFlight(idx);
            probeR = sp.controller.probeRepumpF;
            shutterR = sp.controller.shutterRepumpF;
            %% First image with atoms
            probe.on(onTime,sp.enableProbe(idx),'ms').after(width,0,'us');
            shutter.anchor(onTime,'ms').before(sp.probeShutterDelay(idx),sp.enableProbe(idx),'ms').on(probe.last,0);
            camTrig.anchor(onTime,'ms').before(sp.camExp(idx),1,'ms').on(probe.last,0);
            
            probeR.anchor(onTime,'ms').before(sp.repumpProbeDelay(idx),sp.enableRepump(idx),'ms')
            shutterR.anchor(probeR.last).before(sp.repumpShutterDelay(idx),sp.enableRepump(idx),'ms');
            probeR.after(sp.repumpProbeWidth(idx),0,'us');
            shutterR.on(probeR.last,0);
            
            %% Second image with atoms
            onTime = onTime+sp.camLoopTime(idx);
            probe.on(onTime,sp.enableProbe(idx),'ms').after(width,0,'us');
            shutter.anchor(onTime,'ms').before(sp.probeShutterDelay(idx),sp.enableProbe(idx),'ms').on(probe.last,0);
            camTrig.anchor(onTime,'ms').before(sp.camExp(idx),1,'ms').on(probe.last,0);
            
            probeR.anchor(onTime,'ms').before(sp.repumpProbeDelay(idx),sp.enableRepump(idx),'ms')
            shutterR.anchor(probeR.last).before(sp.repumpShutterDelay(idx),sp.enableRepump(idx),'ms');
            probeR.after(sp.repumpProbeWidth(idx),0,'us');
            shutterR.on(probeR.last,0);
            
            %% Third image without atoms
            onTime = onTime+sp.camLoopTime(idx);
            camTrig.on(onTime,1,'ms').before(sp.camExp(idx),1,'ms').sort.after(width,0,'us');
            
        end
        
        function sp = makeDoubleImageSeq(sp,idx)
            if nargin < 2
                idx = 1;
            end
            if iscell(sp.probeType)
                pt = sp.probeType{idx};
            else
                pt = sp.probeType;
            end
            switch upper(pt)
                case 'RBRB'
                    width1 = sp.probeWidthRb(idx);
                    width2 = sp.probeWidthRb(idx);
                    probe1 = sp.controller.probeRb;
                    probe2 = sp.controller.probeRb;
                    shutter1 = sp.controller.shutterRb;
                    shutter2 = sp.controller.shutterRb;
                case 'RBK'
                    width1 = sp.probeWidthRb(idx);
                    width2 = sp.probeWidthK(idx);
                    probe1 = sp.controller.probeRb;
                    probe2 = sp.controller.probeK;
                    shutter1 = sp.controller.shutterRb;
                    shutter2 = sp.controller.shutterK;
                case 'KRB'
                    width1 = sp.probeWidthK(idx);
                    width2 = sp.probeWidthRb(idx);
                    probe1 = sp.controller.probeK;
                    probe2 = sp.controller.probeRb;
                    shutter1 = sp.controller.shutterK;
                    shutter2 = sp.controller.shutterRb;
                case 'KK'
                    width1 = sp.probeWidthK(idx);
                    width2 = sp.probeWidthK(idx);
                    probe1 = sp.controller.probeK;
                    probe2 = sp.controller.probeK;
                    shutter1 = sp.controller.shutterK;
                    shutter2 = sp.controller.shutterK;
                otherwise
                    error('Double imaging case not supported')
            end
            
            camTrig = sp.controller.camTrig;
            onTime = sp.crossbeamOnTime(idx)+sp.timeOfFlight(idx);
            delay = max(sp.imageDelay(idx),sp.ANDOR_READ_TIME);
            
            probeR = sp.controller.probeRepumpF;
            shutterR = sp.controller.shutterRepumpF;
            %% Zeroeth, throw-away image for Andor iXon camera in frame-transfer mode
            camTrig.anchor(onTime,'ms').before(sp.ANDOR_FIRST_LOOP_TIME,1,'ms').after(sp.camExp(idx),0,'ms');
            
            %% First images with atoms
            shutter1.anchor(onTime,'ms').before(sp.probeShutterDelay(idx),sp.enableProbe(idx),'ms').sort;
            shutter2.anchor(onTime,'ms').before(sp.probeShutterDelay(idx),sp.enableProbe(idx),'ms').sort;
            
            probe1.on(onTime,sp.enableProbe(idx),'ms').after(width1,0,'us');
            camTrig.on(probe1.last,0).before(sp.camExp(idx),1,'ms');
            
            probe2.anchor(probe1.last).after(sp.imageDelay(idx),sp.enableProbe(idx),'ms').after(width2,0,'us');
            shutter1.on(probe2.last,0);
            shutter2.on(probe2.last,0);
            
            camTrig.after(delay,1,'ms').after(sp.camExp(idx),0,'ms');
            
            probeR.anchor(onTime,'ms').before(sp.repumpProbeDelay(idx),sp.enableRepump(idx),'ms');
            shutterR.anchor(probeR.last).before(sp.repumpShutterDelay(idx),sp.enableRepump(idx),'ms');
            probeR.after(sp.repumpProbeWidth(idx),0,'us');
            shutterR.on(probeR.last,0);
            
            %% Second images without atoms
            onTime = onTime+delay+sp.camLoopTime(idx);
            shutter1.anchor(onTime,'ms').before(sp.probeShutterDelay(idx),sp.enableProbe(idx),'ms').sort;
            shutter2.anchor(onTime,'ms').before(sp.probeShutterDelay(idx),sp.enableProbe(idx),'ms').sort;
            probe1.on(onTime,sp.enableProbe(idx),'ms').after(width1,0,'us');
            camTrig.on(probe1.last,0).before(sp.camExp(idx),1,'ms');
            
            probe2.anchor(probe1.last).after(sp.imageDelay(idx),sp.enableProbe(idx),'ms').after(width2,0,'us');
            shutter1.on(probe2.last,0);
            shutter2.on(probe2.last,0);
            camTrig.after(delay,1,'ms').after(sp.camExp(idx),0,'ms');
            
            probeR.anchor(onTime,'ms').before(sp.repumpProbeDelay(idx),sp.enableRepump(idx),'ms');
            shutterR.anchor(probeR.last).before(sp.repumpShutterDelay(idx),sp.enableRepump(idx),'ms');
            probeR.after(sp.repumpProbeWidth(idx),0,'us');
            shutterR.on(probeR.last,0);
            
            %% Third dark images
            onTime = onTime+delay+sp.camLoopTime(idx);
            camTrig.on(onTime,0,'ms').before(sp.camExp(idx),1,'ms');
            camTrig.after(delay,1,'ms').after(sp.camExp(idx),0,'ms');
            
        end
        
        
        function sp = makeSequence(sp,idx)
            if nargin < 2
                idx = 1;
            end
            sp.controller.laser.on(0,1).after(sp.crossbeamOnTime(idx)+sp.additionalWaveguideOnTime(idx),0,'ms');
            if iscell(sp.probeType)
                pt = sp.probeType{idx};
            else
                pt = sp.probeType;
            end
            switch upper(pt)
                case {'RB','K','V','F'}
                    sp.makeSingleImageSeq(idx);
                case {'RBRB','KK','RBK','KRB'}
                    sp.makeDoubleImageSeq(idx);
                otherwise
                    error('Probe type %s not supported!',sp.probeType(idx));
            end
            tc = sp.controller;
            sp.pulses.makeSequences(tc.mw,tc.rf,tc.pulseType,idx);
            
        end
        
        
        function sp = upload(sp)
            if sp.numConfigs == 1
                sp.controller.open;
                sp.flexDDSTriggers.upload(sp.controller.ser);
                sp.controller.upload;
            else
%                 delete(sprintf('%s*',sp.file.dir));
                for nn = 1:sp.numConfigs
                    sp.makeSequence(nn);
                    dev = fopen(sprintf('%s%s_%d',sp.file.dir,sp.file.base,nn),'w');
                    sp.flexDDSTriggers.upload(dev);
                    sp.controller.upload(dev);
                end
            end
            
        end
        
        
        
    end
    
    
    
end