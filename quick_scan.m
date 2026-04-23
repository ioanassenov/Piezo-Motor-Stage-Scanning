% Title: Inertial Drive Stage 2 Dimensional Continuous Scan
% Filename: quick_scan.m
% Author: Ioan Assenov
%
% Description: This file is used as a test to both move the stages and
% record data from the photomultiplier tube at the same time. It scans
% along a given width and height (in steps) while continuously collecting
% data.
%
% Program output: rawData.mat -> a cell array with the raw data from the
% photomultiplier tube organized by row.

try
    device.Disconnect(); % Disconnect device if it hasn't been already
end
clear; clc;

%% Scan parameters
% To scan a single row, set the endYPos equal to the increment

INCREMENT = 20;    % [steps] define distance moved between rows
ENDXPOS   = 10800; % [steps] define the final X value of the rows
XERR      = 0;  % [steps] additional steps for reverse motion
STARTYPOS = 3700;  % [steps] desired y offset from origin to start scan from.
ENDYPOS   = 7000;  % [steps] define the final Y value of the columns from startYPos

% Single row scan settings 
STARTYPOS = 0;
ENDYPOS = INCREMENT;

%% DAQ Setup
dq = daq("ni"); % Initialize a DataAcquisition interface object for an NI device
dq.Rate = 250e3;         % Set rate [Hz] - 2e6 with OLDHAM5 and 250e3 with OLDHAM3
% dqID = "PCIE6374_BNC"; % (OLDHAM5 Computer)
% dqID = "PCI6221_bnc";    % (OLDHAM3 Computer)
dqID = "Dev1";
ainPin = "ai0";
in1 = addinput(dq, dqID, ainPin, "Voltage"); % Create input channel that we read data from
varName = dqID + "_" + ainPin; % Assemble variable name of input for convenient table indexing

%% Stage Movement Setup
devCLI = NET.addAssembly(fullfile(pwd, "kinesis_dlls\Thorlabs.MotionControl.DeviceManagerCLI.dll"));
genCLI = NET.addAssembly(fullfile(pwd, "kinesis_dlls\Thorlabs.MotionControl.GenericMotorCLI.dll"));
motCLI = NET.addAssembly(fullfile(pwd, "kinesis_dlls\Thorlabs.MotionControl.KCube.InertialMotorCLI.dll"));

import Thorlabs.MotionControl.DeviceManagerCLI.*
import Thorlabs.MotionControl.GenericMotorCLI.*
import Thorlabs.MotionControl.KCube.InertialMotorCLI.*

% Builds Device list
DeviceManagerCLI.BuildDeviceList();

% Pull the Enums needed
channelsHandle = motCLI.AssemblyHandle.GetType('Thorlabs.MotionControl.KCube.InertialMotorCLI.InertialMotorStatus+MotorChannels');
channelsEnums = channelsHandle.GetEnumValues();

serialNum = '97100466'; % Serial number for KIM101 controller in Prof. Oldham's lab
timeout = 60000; % Movement timeout before skipping (milliseconds?)

% Connect to controller
device = KCubeInertialMotor.CreateKCubeInertialMotor(serialNum);
device.Connect(serialNum);
device.WaitForSettingsInitialized(5000);

device.StartPolling(250);
device.EnableDevice();
pause(1) % Wait to make sure device is enabled

% Redefine .NET assembly properties in convenient variables
PD1 = channelsEnums.GetValue(0); % Channel 1 is the x stage
PD2 = channelsEnums.GetValue(1); % Channel 2 is the y stage

% Define convenient MoveBy() function handles
move1 = @(steps) device.MoveBy(PD1, int32(steps), timeout);
move2 = @(steps) device.MoveBy(PD2, int32(steps), timeout);


% Try/Catch statement used to disconnect stage controller correctly if error occurs
try 
    % Zero the actuators
    disp("Zeroing actuators 1 & 2")
    device.SetPositionToZero(PD1);
    device.SetPositionToZero(PD2);
    
    %% Define movement parameters
    % Define new drive parameters object and configure it
    driveParams = Thorlabs.MotionControl.KCube.InertialMotorCLI.DriveParams;
    driveParams.StepRate = 2000; % can go up to 2500 [steps/s]
    device.SetDriveParameters(PD1, driveParams); % Apply drive parameters to PD1
    device.SetDriveParameters(PD2, driveParams); % Apply drive parameters to PD2
    
    % ========================== START Movements ==========================
    % Make sure the y position bounds are valid
    if ENDYPOS - STARTYPOS < 0
        error("startYPos cannot exceed endYPos!");
    end

    % Define total number of rows for convenience (note the first row is 0)
    totalRows = floor((ENDYPOS-STARTYPOS)/INCREMENT) + 1;

    % Initialize empty row data cell array
    rawData = cell(totalRows, 1);

    % Start stop watch and define pause durations
    scanTime = tic;
    % shortpause = 1/dq.Rate;
    shortpause = 0.001;
    longpause = 0.05;

    % Move to starting y location before scan loop begins. Skip this step
    % if STARTYPOS is set to zero.
    if STARTYPOS
        fprintf("Moving to starting Y position: %d\n", STARTYPOS);
        move2(-STARTYPOS);
    end
    disp("Beginning scan...")
    % Initialize progress bar
    progBar = waitbar(0, "Beginning scan...", "Name", sprintf("Quick scan of %d rows", totalRows));

    % Move through entire row/col range (subtract increment since we start at 0)
    row = 0;
    scanAttempts = 1;
    while row <= ENDYPOS - STARTYPOS
        tRow = tic; % (Re)start row stopwatch

        % Define current row number for convenience and update progress bar
        currentRow = row/INCREMENT + 1;
        waitbar(currentRow/totalRows, progBar, sprintf("Scanning row %d of %d (attempt %d)...", ...
            currentRow, totalRows, scanAttempts));
     
        % Begin scanning along row & store raw data for the current row
        start(dq, "continuous");
        move1(ENDXPOS);
        pause(shortpause); % Infinitesimal pause needed for DAQ to find its data (why?)
        rawRowData = read(dq, "all", OutputFormat="Matrix");

        % Stop data acquisition for current row
        stop(dq);
        flush(dq);
        pause(longpause);

        % Move the x stage back to the beginning before starting new row
        move1(-ENDXPOS-XERR);

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
        move2(-INCREMENT);
        
        % Take row time, calculate remaining time to completion and display
        rowTime = toc(tRow);
        estRemaining = toc(tRow) * (totalRows-currentRow);
        fprintf("Row %d/%d scanned in %f sec after %d attempt(s). ~%dm %ds remaining.\n", ...
            currentRow, totalRows, rowTime, scanAttempts, floor(estRemaining/60), int16(mod(estRemaining, 60)));

        % Increment row location (steps) & reset attempts counter
        row = row + INCREMENT;
        scanAttempts = 1;
    end
    % =========================== END Movements ===========================
        
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


% Save scan file in current directory
t = datetime;
t.Format = 'yyyy-MM-dd''T''HHmm';
filename = strcat("scan",string(t),".mat");
save(filename, "rawData");
fprintf("Saved scan data to %s\n", filename);
