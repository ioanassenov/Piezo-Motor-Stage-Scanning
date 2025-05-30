% Title: Inertial Drive Stage (IDS) Scanning Autosequence
% Filename: ids_scanning_movement.m
% Author: Ioan Assenov
%
% Based on code from the original Thorlabs Git repository
% GitHub Repo: https://github.com/Thorlabs/Motion_Control_Examples/tree/main/Matlab

clear; close all;

devCLI = NET.addAssembly(fullfile(pwd, "kinesis_dlls\Thorlabs.MotionControl.DeviceManagerCLI.dll"));
genCLI = NET.addAssembly(fullfile(pwd, "kinesis_dlls\Thorlabs.MotionControl.GenericMotorCLI.dll"));
motCLI = NET.addAssembly(fullfile(pwd, "kinesis_dlls\Thorlabs.MotionControl.KCube.InertialMotorCLI.dll"));

import Thorlabs.MotionControl.DeviceManagerCLI.*
import Thorlabs.MotionControl.GenericMotorCLI.*
import Thorlabs.MotionControl.KCube.InertialMotorCLI.*

% Builds Device list
DeviceManagerCLI.BuildDeviceList();

% Will need to update serial number to correct device
serial_num='97100466'; % Serial number for KIM101 controller in Prof. Oldham's lab
timeout=60000;

% Connect to controller
device = KCubeInertialMotor.CreateKCubeInertialMotor(serial_num);
device.Connect(serial_num);

% Try/Catch statement used to disconnect correctly if error occurs
try
    device.WaitForSettingsInitialized(5000);
    
    device.StartPolling(250);
    device.EnableDevice();
    pause(1) % Wait to make sure device is enabled
    
    % Pull the Enums needed
    channelsHandle = motCLI.AssemblyHandle.GetType('Thorlabs.MotionControl.KCube.InertialMotorCLI.InertialMotorStatus+MotorChannels');
    channelsEnums = channelsHandle.GetEnumValues();
    jogDirectionHandle = motCLI.AssemblyHandle.GetType('Thorlabs.MotionControl.KCube.InertialMotorCLI.InertialMotorJogDirection');
    jogDirectionEnums = jogDirectionHandle.GetEnumValues();
    
    % Redefine .NET assembly properties in convenient variables
    jogFwd = jogDirectionEnums.GetValue(0); % Jog Direction Forward
    jogRev = jogDirectionEnums.GetValue(1); % Jog Direction Reverse
    PD1 = channelsEnums.GetValue(0);        % Channel 1 is the x stage
    PD2 = channelsEnums.GetValue(1);        % Channel 2 is the y stage
    
    % Zero the actuators
    disp("Zero actuators 1 & 2")
    device.SetPositionAs(PD1, 0);
    device.SetPositionAs(PD2, 0);

    % Define convenient MoveBy() function handles
    move1 = @(steps) device.MoveBy(PD1, int32(steps), timeout);
    move2 = @(steps) device.MoveBy(PD2, int32(steps), timeout);

    % ######################## Movements ########################
    increment = 100;              % [steps] define the distance y moves after each row is scanned
    endYPos = 4000;                % [steps] maximum y position
    rowsCount = endYPos/increment; % Total number of rows
    rowWidth = 2000;
    currentRow = 0;

    % Loop through all rows. Twice the increment is used since two rows are done per loop.
    for ypos = 1:increment*2:endYPos
        currentRow = currentRow + 1;
        disp(strcat("Scanning row ", string(currentRow), "/", string(rowsCount)));
        move1(2000);         % Scan along x
        move2(-1*increment); % Move up 1 row

        currentRow = currentRow + 1;
        disp(strcat("Scanning row ", string(currentRow), "/", string(rowsCount)));
        move1(-3850);         % Scan along x in opposite direction
        move2(-1*increment); % Move up 1 more row
    end
    disp("Scan completed!")

catch err
    disp("Error has caused the program to stop, disconnecting...")
    disp(err.identifier);
    disp(err.message);
end

%% Disconnect from controller
disp("Program ended, disconnecting from controller...")
device.StopPolling();
device.Disconnect();