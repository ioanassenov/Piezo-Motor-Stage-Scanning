% Title: Inertial Drive Stage 2 Dimensional Scan
% Filename: rowcol_scan.m
% Author: Ioan Assenov
%
% Description: This file is used as a test to both move the stages and
% record data from the photomultiplier tube at the same time. It scans
% along a given width and height (in steps) and displays the data in a
% heatmap visualization

clear; clc;

%% DAQ Setup
dq = daq("ni"); % Initialize a DataAcquisition interface object for an NI device
dq.Rate = 2e6;  % Set rate (Hertz)
dqID = "PCIE6374_BNC"; % DAQ ID number is based on the PCI card
in1 = addinput(dq, dqID, "ai0", "Voltage"); % Create input channel that we read data from

%% Stage Movement Setup
devCLI = NET.addAssembly(fullfile(pwd, "kinesis_dlls\Thorlabs.MotionControl.DeviceManagerCLI.dll"));
genCLI = NET.addAssembly(fullfile(pwd, "kinesis_dlls\Thorlabs.MotionControl.GenericMotorCLI.dll"));
motCLI = NET.addAssembly(fullfile(pwd, "kinesis_dlls\Thorlabs.MotionControl.KCube.InertialMotorCLI.dll"));

import Thorlabs.MotionControl.DeviceManagerCLI.*
import Thorlabs.MotionControl.GenericMotorCLI.*
import Thorlabs.MotionControl.KCube.InertialMotorCLI.*

% Builds Device list
DeviceManagerCLI.BuildDeviceList();

% Will need to update serial number to correct device
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
    PD1 = channelsEnums.GetValue(0);        % Channel 1 is the x stage
    PD2 = channelsEnums.GetValue(1);        % Channel 2 is the y stage
    
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

    increment = 100;  % [steps] define distance moved between scans on same row and between rows
    endXPos = 10000; % [steps] define the final X value of the rows
    xerr = 1200;     % [steps] additional steps for reverse motion
    endYPos = increment*50; % [steps] define the final Y value of the columns
    data = zeros(endYPos/increment, endXPos/increment); % Initialize empty data vector

    % Define total number of rows/columns for convenience
    totalRows = endYPos / increment;
    totalCols = endXPos / increment;

    tTotal = tic;       % Start stopwatch
    start(dq); % Start background data collection
    % Move through entire row/col range (subtract increment since we start at 0)
    for row = 0:increment:(endYPos-increment)
        % Define current row number for convenience
        currentRow = row/increment + 1;
        
        tCol = tic;
        % Begin scanning along row
        for col = 0:increment:(endXPos-increment)
            % Define current column for convenience
            currentCol = col/increment + 1;
           
            % Read the data for 100us, rename the variable for convenience,
            % take the mean value, and store it for the given position.
            rawData = read(dq, seconds(100e-6));
            data(currentRow, currentCol) = mean(rawData.PCIE6374_BNC_ai0);
             
            % Display location info & reading
            fprintf("Scanning row: %d/%d | col: %d/%d | data %f V\n", ...
                currentRow, totalRows, currentCol, totalCols, data(currentRow, currentCol));

            % Move the x stage by the defined increment
            move1(increment);
        end
        % Move the x stage back to the beginning before starting new row
        move1(-endXPos - xerr);
        % Move the y stage to the next row after completing the x movements
        move2(-increment);

        toc(tCol);
    end
    
    % Stop data collection and clean up
    stop(dq);
    dq.flush();
    
catch err
    disp("Error has caused the program to stop, disconnecting...")
    disp(err.identifier);
    disp(err.message);
end

%% Disconnect from controller
disp("Program ended, disconnecting from controller...")
fprintf("Scanned %d row(s) and %d column(s) in %f seconds.\n", totalRows, totalCols, toc(tTotal))
device.StopPolling();
device.Disconnect();

%% Rotate data and display in heatmap
data = rot90(data, 2); % Rotate data upside down to match actual target orientation
% Create figure with date and time of scan and plot data as heatmap
% figure(Name=string(datetime));
% heatmap(data);