clear; close all;

%% DAQ initialization

% This function finds all the DAQ system by National  Instruments (NI)
d = daqlist("ni");

% Fetch info about the DAQ (No. inputs/outputs, max sample frequency, etc.)
deviceinfo1 = d{1,"DeviceInfo"};

% This function creates a DataAcquisition interface object for a National Instruments device
dq = daq("ni");

% Specify the sampling frequency. The maximum sampling frequency will be
% used if the assigned value exceeds it.
dq.Rate = 2e4;

%% I/O Specification
% Specify DAQ id, this depends on the PCI card that it is connected to and
% can be fetched with the daqlist() function.
dqID = "PCIE6374_BNC";

% Define DAQ input and outputs
in1 = addinput(dq, dqID, "ai0", "Voltage");

%% Data Collection
% Read data from dq object for given time duration in seconds
data = read(dq, seconds(1));
% save('noisedata200khzfloor',"data")

% Rename ai0 default name for convenience
data = renamevars(data, "PCIE6374_BNC_ai0", "ai0");

% Average the data over the time duration
dataAvg = mean(data.ai0)