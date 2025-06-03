% Title: Inertial Drive Stage 2 Dimensional Continuous Scan
% Filename: quick_scan.m
% Author: Ioan Assenov
%
% Description: This file is used as a test to both move the stages and
% record data from the photomultiplier tube at the same time. It scans
% along a given width and height (in steps) while continuously collecting
% data. It then parses it and displays the data in a heatmap visualization.
%
% Program output: rawData.mat -> a cell array with the raw data from the
% photomultiplier tube organized by row.

clear; clc;

%% DAQ Setup
dq = daq("ni"); % Initialize a DataAcquisition interface object for an NI device
dq.Rate = 250e3;         % Set rate [Hz] - 2e6 with OLDHAM5 and 250e3 with OLDHAM3
% dqID = "PCIE6374_BNC"; % (OLDHAM5 Computer)
dqID = "PCI6221_bnc";    % (OLDHAM3 Computer)
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
    disp("Zeroing actuators 1 & 2")
    device.SetPositionToZero(PD1);
    device.SetPositionToZero(PD2);
    
    %% Define movement parameters
    % Define new drive parameters object and configure it
    driveParams = Thorlabs.MotionControl.KCube.InertialMotorCLI.DriveParams;
    driveParams.StepRate = 2500; % can go up to 2500 [steps/s]
    device.SetDriveParameters(PD1, driveParams); % Apply drive parameters to PD1
    device.SetDriveParameters(PD2, driveParams); % Apply drive parameters to PD2

    % Define convenient MoveBy() function handles
    move1 = @(steps) device.MoveBy(PD1, int32(steps), timeout);
    move2 = @(steps) device.MoveBy(PD2, int32(steps), timeout);

    % ######################## Movements ########################
    % To scan a single row, set the endYPos equal to the increment

    increment = 15;  % [steps] define distance moved between rows
    endXPos = 11200; % [steps] define the final X value of the rows
    xerr = 1250;      % [steps] additional steps for reverse motion
    endYPos = 11000; % [steps] define the final Y value of the columns
    % endYPos = increment; % [steps] single row scan

    % Define total number of rows for convenience (note the first row is 0)
    totalRows = floor(endYPos/increment) + 1;

    % Initialize empty row data cell array
    rawData = cell(totalRows, 1);

    % Start data acquisition & stopwatch
    scanTime = tic;

    % Define pause lengths
    % shortpause = 1/dq.Rate;
    shortpause = 0.001;
    longpause = 0.05;

    
    % Display begin status and initialize progress bar
    disp("Beginning scan...")
    progBar = waitbar(0, "Beginning scan...", "Name", sprintf("Quick scan of %d rows", totalRows));

    % Move through entire row/col range (subtract increment since we start at 0)
    row = 0;
    scanAttempts = 1;
    while row <= endYPos
        tRow = tic; % (Re)start row stopwatch

        % Define current row number for convenience and update progress bar
        currentRow = row/increment + 1;
        waitbar(currentRow/totalRows, progBar, sprintf("Scanning row %d of %d (attempt %d)...", ...
            currentRow, totalRows, scanAttempts));
     
        % Begin scanning along row & store raw data for the current row
        start(dq, "continuous");
        move1(endXPos);
        pause(shortpause); % Infinitesimal pause needed for DAQ to find its data (why?)
        rawRowData = read(dq, "all", OutputFormat="Matrix");

        % Stop data acquistion for current row
        stop(dq);
        flush(dq);
        pause(longpause);

        % Move the x stage back to the beginning before starting new row
        move1(-endXPos-xerr);

        % Store collected raw data for the row in the raw cell array.
        rawData{currentRow} = rawRowData;

        % Check to see that data was in fact collected and row is not empty
        % if it is, display a warning, decrease row increment, and retry.
        if isempty(rawData{currentRow})
            warning("No data collected for row %d, retrying...", currentRow);
            currentRow = currentRow - 1;
            scanAttempts = scanAttempts + 1;
            continue; % Restart the loop before we increment in y
        end

        % Move the y stage to the next row after completing the x movements
        % provided data collection for the row was successful.
        move2(-increment);
        
        % Take row time, calculate remaining time to completion and display
        rowTime = toc(tRow);
        estRemaining = toc(tRow) * (totalRows-currentRow);
        fprintf("Row %d/%d scanned in %f sec after %d attempt(s). ~%dm %ds remaining.\n", ...
            currentRow, totalRows, rowTime, scanAttempts, floor(estRemaining/60), int16(mod(estRemaining, 60)));

        % Increment row location (steps) & reset attempts counter
        row = row + increment;
        scanAttempts = 1;
    end
        
catch err
    disp("Error has caused the program to stop, disconnecting...")
    disp(err.identifier);
    disp(err.message);
    device.StopPolling();
    device.Disconnect();
end


%% Disconnect and stop data collection
disp("Program ended, disconnecting from controller...")
time = toc(scanTime);
fprintf("Scanned %d row(s) in %d min %f sec.\n", currentRow, int16(time/60), mod(time, 60))
device.StopPolling();
device.Disconnect();

% Stop data collection and clean up
stop(dq);
flush(dq);
close(progBar); % Close progress bar window

%% Save scan file in current directory
t = datetime;
t.Format = 'yyyy-MM-dd''T''HHmm';
filename = strcat("scan",string(t),".mat");
save(filename, "rawData");
fprintf("Saved scan data to %s\n", filename);