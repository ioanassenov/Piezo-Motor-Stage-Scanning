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

% Will need to update serial number to correct device
serial_num='97100466'; % Serial number for KIM101 controller in Prof. Oldham's lab
timeout_val=60000;

%Connect to controller
device = KCubeInertialMotor.CreateKCubeInertialMotor(serial_num);
device.Connect(serial_num);
