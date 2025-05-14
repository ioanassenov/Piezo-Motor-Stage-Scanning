%% Header

% Title: Sandbox file for testing purposes
% Filename: testing.m
% Author: Ioan Assenov

%% Add and Import Assemblies
devCLI = NET.addAssembly('.\dll\Thorlabs.MotionControl.DeviceManagerCLI.dll');
genCLI = NET.addAssembly('.\dll\Thorlabs.MotionControl.GenericMotorCLI.dll');
motCLI = NET.addAssembly('.\dll\Thorlabs.MotionControl.KCube.InertialMotorCLI.dll');

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
    pause(1) %wait to make sure device is enabled
    
    % Pull the Enums needed
    channelsHandle = motCLI.AssemblyHandle.GetType('Thorlabs.MotionControl.KCube.InertialMotorCLI.InertialMotorStatus+MotorChannels');
    channelsEnums = channelsHandle.GetEnumValues();
    jogDirectionHandle = motCLI.AssemblyHandle.GetType('Thorlabs.MotionControl.KCube.InertialMotorCLI.InertialMotorJogDirection');
    jogDirectionEnums = jogDirectionHandle.GetEnumValues();
    PDChannel1 = channelsEnums.GetValue(0); 
    PDChannel2 = channelsEnums.GetValue(1);
    

catch error
    disp("Error has caused the program to stop, disconnecting...")
    disp(error.identifier);
    disp(error.message);
end
