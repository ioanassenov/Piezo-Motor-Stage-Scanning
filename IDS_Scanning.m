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
timeout_val=60000;

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
    PDChannel1 = channelsEnums.GetValue(0); 
    PDChannel2 = channelsEnums.GetValue(1);
    
    % Zero the actuators
    disp("Zero actuators 1 & 2")
    device.SetPositionAs(PDChannel1, 0);
    device.SetPositionAs(PDChannel2, 0);
    
    % Move X actuator to position
    %device.MoveBy(PDchannel1, 1000, timeout_val);
    device.Jog(PDChannel1, jogDirectionEnums.GetValue(0), timeout_val);

catch error
    disp("Error has caused the program to stop, disconnecting...")
    disp(error.identifier);
    disp(error.message);
end

%Disconnect from controller
disp("Program ended, disconnecting from controller...")
device.StopPolling();
device.Disconnect();