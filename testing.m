%% Header

% Title: Sandbox file for testing purposes
% Filename: testing.m
% Author: Ioan Assenov

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

% Serial number must match controller
serial_num='97100466';  % Serial number for KIM101 controller in Prof. Oldham's lab
timeout=60000;          % Milliseconds?

%Connect to controller
device = KCubeInertialMotor.CreateKCubeInertialMotor(serial_num);
device.Connect(serial_num);
disp("Successfully connected to device!")

% Try/Catch statement used to disconnect correctly if error occurs

try
    device.WaitForSettingsInitialized(5000);
    
    device.StartPolling(250);
    device.EnableDevice();
    pause(1) %wait to make sure device is enabled
    
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
    
    % How to extract methods and properties from .NET Assembly:
    % To view assembly methods:    methods(.NET Assembly) or methodsview(.NET Assembly)
    % To view assembly properties: properties(.NET Assembly)

    % Compilation of useful functions:
    % device.GetPosition(channel)
    % device.GetDriveParameters(channel)
    % device.GetJogParameters(channel)
    % device.SetJogParameters(channel, jogParameters)
    % device.Jog(channel, JogDirection, timeout)

    %% Define movement parameters
    % Define new jog parameters object and configure it
    jogParams = Thorlabs.MotionControl.KCube.InertialMotorCLI.JogParams;
    jogParams.JogStepFwd = 2000; % Set forward step size
    jogParams.JogStepRev = 4950; % Set backward step size (larger value due to reverse movement hysteresis)
    device.SetJogParameters(PD1, jogParams);

    %% Movements

    for c = 1:10
        fprintf("Loop count: "); disp(c);
        disp("Starting forward jog...");
        device.Jog(PD1, jogFwd, timeout);
        disp("Finished forward jog.");
        pause(2);
        disp("Staring reverse jog...");
        device.Jog(PD1, jogRev, timeout);
        disp("Finished reverse jog.");
    end

catch error
    disp("Error has caused the program to stop, disconnecting...")
    disp(error.identifier);
    disp(error.message);
end

%Disconnect from controller
disp("Program completed, disconnecting device...")
device.StopPolling();
device.Disconnect();