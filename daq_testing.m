clear; close all;

%% DAQ initialization

% This function finds all the DAQ system by National  Instruments (NI)
d = daqlist("ni")

% Fetch info about the DAQ (No. inputs/outputs, max sample frequency, etc.)
deviceinfo1 = d(1,"DeviceInfo")

% This function creates a DataAcquisition interface object for a National Instruments device
dq = daq("ni");

% Specify the sampling frequency. The maximum sampling frequency will be
% used if the assigned value exceeds it.
dq.Rate = 2e4;

%% I/O Specification

% Below is the functions that setup the inputs and outputs for the DAQ.
% Depending on the computer you are using, the name of the DAQ is
% different. For "OLDHAM3", the name is 'PCI6221_bnc'. For "OLDHAM5", the
% name is 'PCIE6374_bnc'. You can double check with the "daqlist" function
% in the previous section. 
dqID = "PCIE6374_BNC";

% Define DAQ input and outputs
ai1 = addinput(dq, dqID, "ai1", "Voltage");
% ai2 = addinput(dq, daqID, "ai2", "Voltage");
% ao0 = addoutput(dq, dqID, "ao1", "Voltage");

%% Data Collection

% If you have both input and output channels specified, use the function
% "readwrite". If you only have input channels, use function "read" instead.
% Below shows an example to output a 1 Hz sine wave while reading from the
% two input channels. 


% data = read(dq,1000,"OutputFormat","Matrix");
% T = 10; t = 0:1/dq.Rate:T;
% V = sin(2*pi*t);
% data = readwrite(dq, V');
data = read(dq, seconds(1), "OutputFormat", "Matrix");
% save('noisedata200khzfloor',"data")

% Convert standard timetable output to table for easier indexing