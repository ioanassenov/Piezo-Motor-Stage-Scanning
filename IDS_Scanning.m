%% Header

% Title: Inertial Drive Stage (IDS) Scanning Autosequence
% Filename: IDS_Scanning.m
% Author: Ioan Assenov

% Based on code from the original THOR Labs Git repository
% GitHub Repo: https://github.com/Thorlabs/Motion_Control_Examples/tree/main/Matlab

%% Start of code
clear all; close all; clc

%% Add and Import Assemblies
devCLI = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.DeviceManagerCLI.dll');
genCLI = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.GenericMotorCLI.dll');
motCLI = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.KCube.InertialMotorCLI.dll');

import Thorlabs.MotionControl.DeviceManagerCLI.*
import Thorlabs.MotionControl.GenericMotorCLI.*
import Thorlabs.MotionControl.KCube.InertialMotorCLI.*

%% Connect
% Builds Device list
DeviceManagerCLI.BuildDeviceList();

% Will need to update serial number to correct device
serial_num='97100466'; % Serial number for KIM101 controller in Prof. Oldham's lab
timeout=60000;

%Connect to controller
device = KCubeInertialMotor.CreateKCubeInertialMotor(serial_num);
device.Connect(serial_num);

% Try/Catch statement used to disconnect correctly if error occurs
try
    device.WaitForSettingsInitialized(5000);
    
    device.StartPolling(250);
    device.EnableDevice();
    pause(1) %wait to make sure device is enabledded
    
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
    
    %% Define movement parameters
    % Define new jog parameters object and configure it
    jogParams = Thorlabs.MotionControl.KCube.InertialMotorCLI.JogParams;
    jogParams.JogStepFwd = 2000;             % Set forward step size
    jogParams.JogStepRev = 3300;             % Set backward step size (larger value due to reverse movement hysteresis)
    jogParams.JogRate = 2000;                % Set jog speed (cycles/sec?)
    device.SetJogParameters(PD1, jogParams); % Apply jog parameters to PD1

    jogParams.JogStepRev = 3000;
    device.SetJogParameters(PD2, jogParams); % Apply jog parameters to PD2

    %% Movements

    for y = 1:1
        for x = 1:1
            fprintf("Loop count: "); disp(x);
            disp("Starting forward jog...");
            device.Jog(PD1, jogFwd, timeout);
            disp("Finished forward jog.");
            pause(2);
            disp("Staring reverse jog...");
            device.Jog(PD1, jogRev, timeout);
            disp("Finished reverse jog.");
        end
        fprintf("Loop count: "); disp(y);
            disp("Starting forward jog...");
            device.Jog(PD2, jogFwd, timeout);
            disp("Finished forward jog.");
            pause(2);
            disp("Staring reverse jog...");
            device.Jog(PD2, jogRev, timeout);
            disp("Finished reverse jog.");
    end

catch err
    disp("Error has caused the program to stop, disconnecting...")
    disp(err.identifier);
    disp(err.message);
end

%Disconnect from controller
disp("Program ended, disconnecting from controller...")
device.StopPolling();
device.Disconnect();