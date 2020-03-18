function varargout = FPGA_Program
%% Define the spartan object
sp = SpartanImaging;

%% Set imaging parameters
sp.probeType = 'Rb';
sp.imageDelay = 0.16;
sp.enableProbe = 1;
sp.enableRepump = 1;

sp.crossbeamOnTime = 50;
sp.timeOfFlight = 20;
sp.additionalWaveguideOnTime = 0;

sp.probeWidthRb = 15;
sp.probeWidthK = 15;
sp.probeWidthV = 15;
sp.probeWidthF = 15;

sp.probeShutterDelay = 2.5;
sp.camDelay = 0.25;
sp.camLoopTime = 30;
sp.repumpProbeWidth = 150;
sp.repumpProbeDelay = 150e-3;
sp.repumpShutterDelay = 2.5;


%% Set state preparation parameters
% sp.pulses.addPulse(410,5,1);        %Rb sweep |2,2> -> |1,1>
% sp.pulses.addPulse(500,37.5e-3,1);  %Rb RH pi-pulse |1,1> -> |2,2>
% sp.pulses.addPulse(510,1,2);        %K RH sweep |9/2,9/2> -> |7/2,7/2>
% sp.pulses.addPulse(516,1,2);        %K RH sweep |9/2,9/2> -> |7/2,7/2>
% sp.pulses.addPulse(595,5,1);        %Rb sweep |1,1> -> |2,2>
% sp.numPulses=sp.pulses.numPulses;

%% Rb magnetic field calibration
% sp.pulses.addPulse(320,5,1);
% sp.pulses.addPulse(1340,10,1);
% sp.pulses.addPulse(1440,5,1);
% sp.pulses.addPulse(1471.825,5,1);
% sp.pulses.addPulse(590,2.5,1);
% sp.pulses.addPulse(595,50e-3,3);



%% Calculate values, check for errors, and write the configuration
sp.expandVariables.makeSequence;
sp.upload;

%% Return variables
if nargout == 1
    varargout{1} = sp;
end


