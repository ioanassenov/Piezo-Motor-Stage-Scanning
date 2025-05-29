% Title: Inertial Drive Stage 2 Dimensional Continuous Scan
% Filename: quick_scan.m
% Author: Ioan Assenov
%
% Description: This file is used as a test to both move the stages and
% record data from the photomultiplier tube at the same time. It scans
% along a given width and height (in steps) and displays the data in a
% heatmap visualization while collecting data continuously

clear; clc;

%% DAQ Setup
dq = daq("ni"); % Initialize a DataAcquisition interface object for an NI device
dq.Rate = 250e3;       % Set rate [Hz] - 2e6 with OLDHAM5 and 250e3 with OLDHAM3
sampleTime = 1e-3;     % Duration of time over which to average readings for scanning [sec]
sampleScans = sampleTime*dq.Rate; % Number of samples over which to collect running average
dqID = "PCIE6374_BNC"; % (OLDHAM5 Computer)
% dqID = "PCI6221_bnc";    % (OLDHAM3 Computer)
ainPin = "ai0";
in1 = addinput(dq, dqID, ainPin, "Voltage"); % Create input channel that we read data from
varName = dqID + "_" + ainPin; % Assemble variable name of input for conveninent table indexing

%% Stage Movement Setup
devCLI = NET.addAssembly(fullfile(pwd, "kinesis_dlls\Thorlabs.MotionControl.DeviceManagerCLI.dll"));
genCLI = NET.addAssembly(fullfile(pwd, "kinesis_dlls\Thorlabs.MotionControl.GenericMotorCLI.dll"));
motCLI = NET.addAssembly(fullfile(pwd, "kinesis_dlls\Thorlabs.MotionControl.KCube.InertialMotorCLI.dll"));

import Thorlabs.MotionControl.DeviceManagerCLI.*
import Thorlabs.MotionControl.GenericMotorCLI.*
import Thorlabs.MotionControl.KCube.InertialMotorCLI.*

% Builds Device list
DeviceManagerCLI.BuildDeviceList();

serialNum = '97100466'; % Serial number for KIM101 controller in Prof. Oldham's lab
timeout = 60000; % Movement timeout before skippnig (milliseconds?)

% Connect to controller
device = KCubeInertialMotor.CreateKCubeInertialMotor(serialNum);
device.Connect(serialNum);

% Try/Catch statement used to disconnect stage controller correctly if error occurs
try
    device.WaitForSettingsInitialized(5000);
    
    device.StartPolling(250);
    device.EnableDevice();
    pause(1) % Wait to make sure device is enabled
    
    % Pull the Enums needed
    channelsHandle = motCLI.AssemblyHandle.GetType('Thorlabs.MotionControl.KCube.InertialMotorCLI.InertialMotorStatus+MotorChannels');
    channelsEnums = channelsHandle.GetEnumValues();
    
    % Redefine .NET assembly properties in convenient variables
    PD1 = channelsEnums.GetValue(0); % Channel 1 is the x stage
    PD2 = channelsEnums.GetValue(1); % Channel 2 is the y stage
    
    % Zero the actuators
    disp("Zero actuators 1 & 2")
    device.SetPositionToZero(PD1);
    device.SetPositionToZero(PD2);
    
    %% Define movement parameters
    % Define new drive parameters object and configure it
    driveParams = Thorlabs.MotionControl.KCube.InertialMotorCLI.DriveParams;
    driveParams.StepRate = 2000;
    device.SetDriveParameters(PD1, driveParams); % Apply drive parameters to PD1
    device.SetDriveParameters(PD2, driveParams); % Apply drive parameters to PD2

    % Define convenient MoveBy() function handles
    move1 = @(steps) device.MoveBy(PD1, int32(steps), timeout);
    move2 = @(steps) device.MoveBy(PD2, int32(steps), timeout);

    % ######################## Movements ########################
    % To scan a single row, set the endYPos equal to the increment

    increment = 50;   % [steps] define distance moved between scans on same row and between rows
    endXPos = 11500;  % [steps] define the final X value of the rows
    xerr = 2000;      % [steps] additional steps for reverse motion
    % endYPos = 11000;% [steps] define the final Y value of the columns
    endYPos = increment*200; % [steps] single row scan

    % Define total number of rows/columns for convenience
    totalRows = endYPos / increment;
    totalCols = endXPos / increment;

    % Initialize empty row data cell array
    rawData = cell(totalRows, 1);


    % Start data acquisition & stopwatch
    scanTime = tic;

    % Define pause lengths
    shortpause = 1/dq.Rate;
    longpause = 0.05;

    % Move through entire row/col range (subtract increment since we start at 0)
    for row = 0:increment:(endYPos-increment)
        tRow = tic; % (Re)start row stopwatch

        % Define current row number for convenience
        currentRow = row/increment + 1;
     
        start(dq, "continuous");
        % Begin scanning along row & store raw data for the current row
        move1(endXPos);
        pause(shortpause); % Infinitesimal pause needed for DAQ to find its data (why?)
        rawRowData = read(dq, "all", OutputFormat="Matrix");

        % Stop data acquistion for current row
        stop(dq);
        flush(dq);
        pause(longpause);

        % Move the x stage back to the beginning before starting new row
        % and clear any accumulated data out of the buffer.
        % pause(longpause); % DAQ needs 30 ms to "rest" (why?)
        move1(-endXPos-xerr);
        % pause(shortpause); % Infinitesimal pause needed for DAQ to find its data (why?)
        % bufferClear = read(dq, "all", OutputFormat="Matrix"); % Clear data
        % pause(longpause); % DAQ needs 30 ms to "rest" (why?)

        % Store collected raw data for the row in the raw cell array.
        rawData{currentRow} = rawRowData;

        % Move the y stage to the next row after completing the x movements
        move2(-increment);
        
        % Take row time, calculate remaining time to completion and display
        rowTime = toc(tRow);
        estRemaining = toc(tRow) * (totalRows-currentRow);
        fprintf("\nRow %d/%d scanned in %f seconds. ~%dm %ds remaining.\n", ...
            currentRow, totalRows, rowTime, int16(estRemaining/60), int16(mod(estRemaining, 60)));
    end
        
catch err
    disp("Error has caused the program to stop, disconnecting...")
    disp(err.identifier);
    disp(err.message);
    device.StopPolling();
    device.Disconnect();
end

%% Downsample data (pixelate) and rotate to display in heatmap
for row=1:length(rawData)
    % Use block processing to divide raw row data up into pixels the size
    % of the totalCols value and average all the values within the pixel.
    rowData = blockproc(rawData{row}, [totalCols, 1], @(x) mean(x.data));

    % Append downsampled row into full image
    imageData{row} = rowData;
end

% Rotate and mirror the data for correct image orientation
imageData = cell2mat(imageData);
imageData = rot90(imageData);
imageData = flip(imageData);

% Create figure with date and time of scan and plot data as heatmap
figure(Name=string(datetime));
h = heatmap(imageData);
h.GridVisible = "off";

%% Disconnect from controller
disp("Program ended, disconnecting from controller...")
fprintf("Scanned %d row(s) and %d column(s) in %f seconds.\n", totalRows, totalCols, toc(scanTime))
device.StopPolling();
device.Disconnect();

% Stop data collection and clean up
stop(dq);
flush(dq);