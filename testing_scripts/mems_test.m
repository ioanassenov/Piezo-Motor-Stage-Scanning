clear; close all;

% Initialize DAQ
dq = daq('ni');
dq.Rate = 250e3;         % Set rate [Hz] - 2e6 with OLDHAM5 and 250e3 with OLDHAM3
% dqID = "PCIE6374_BNC"; % (OLDHAM5 Computer)
dqID = "PCI6221_bnc";    % (OLDHAM3 Computer)
aInPin = "ai0";
aOutPin = "ao0";
in1 = addinput(dq, dqID, aInPin, "Voltage"); % Create input channel that we read data from
out1 = addoutput(dq, dqID, aOutPin, "Voltage"); % Create output channel for mirror movements
varName = dqID + "_" + aInPin; % Assemble variable name of input for conveninent table indexing

% DAQ output (system input) definition
t = linspace(0, 1, dq.Rate);

% Vdc = 4;
% Vacx = 4;
% Vacy = 2;
% fx = 5;
% fy = 2;
% phiy = 0.8;

Vdc = 3;
Vacx = 4;
Vacy = 3;
fx = 64;
fy = 105;
phiy = 0.8;


Vdrive = Vdc + Vacx*sin(2*pi*fx*t) + Vacy*sin(2*pi*fy*t + phiy);

% Write output for continuous movements
disp("Writing output to DAQ continuously.") 
start(dq, 'repeatoutput');
write(dq, Vdrive');

%% Stop and clean up
disp("Stopping DAQ and cleaning up.")
stop(dq);
flush(dq);