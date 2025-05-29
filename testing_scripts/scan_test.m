clear;

%% DAQ Setup
dq = daq("ni");
dq.Rate = 250e3;
dqID = "PCIE6374_BNC";
ainPin = "ai0";
in1 = addinput(dq, dqID, ainPin, "Voltage");
varName = dqID + "_" + ainPin;

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

% Pull the Enums needed
channelsHandle = motCLI.AssemblyHandle.GetType('Thorlabs.MotionControl.KCube.InertialMotorCLI.InertialMotorStatus+MotorChannels');
channelsEnums = channelsHandle.GetEnumValues();

% Redefine .NET assembly properties in convenient variables
PD1 = channelsEnums.GetValue(0); % Channel 1 is the x stage
PD2 = channelsEnums.GetValue(1); % Channel 2 is the y stage

% Connect to controller
device = KCubeInertialMotor.CreateKCubeInertialMotor(serialNum);
device.Connect(serialNum);

device.StartPolling(250);
device.EnableDevice();
pause(1) % Wait to make sure device is enabled

% Define new drive parameters object and configure it
driveParams = Thorlabs.MotionControl.KCube.InertialMotorCLI.DriveParams;
driveParams.StepRate = 2000;
device.SetDriveParameters(PD1, driveParams); % Apply drive parameters to PD1
device.SetDriveParameters(PD2, driveParams); % Apply drive parameters to PD2
move1 = @(steps) device.MoveBy(PD1, int32(steps), timeout);
move2 = @(steps) device.MoveBy(PD2, int32(steps), timeout);

%% Useful variables
increment = 50;  % [steps] define distance moved between scans on same row and between rows
endXPos = 11500;  % [steps] define the final X value of the rows
xerr = 0;         % [steps] additional steps for reverse motion







%% Code
start(dq, "continuous");
move1(endXPos);
pause(1/dq.Rate); % infinitesimal pause needed for the daq to find its data (why?)
[dataFwd] = read(dq, "all", OutputFormat="Matrix");
stop(dq);
flush(dq);
pause(0.02); % longer pause required after data has been read (why?)

start(dq, "continuous");
move1(-endXPos);
pause(1/dq.Rate); % infinitesimal pause needed for the daq to find its data (why?)
[dataRev, dataTime] = read(dq, "all", OutputFormat="Matrix");
figure(Name=string(datetime));
hold on;
plot(dataFwd, "Color","blue");
plot(dataRev, "Color","red");
hold off




%% Disconnect
disp("Program ended, disconnecting from controller...")
device.StopPolling();
device.Disconnect();
stop(dq);
flush(dq);