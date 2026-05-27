% Title: Inertial Drive Stage 2 Dimensional Continuous Scan with Sensing
% Filename: closed_loop_quickscan.m
% Author: Ioan Assenov
%
% Description: This file is used to both move the stages and record data
% from the photomultiplier tube at the same time. It scans along a given
% width and height (in steps) while continuously collecting data. This
% script controls the THORLABS stages AND collects reflection data using
% solely the NI DAQ.
% 
%
% Program output: rawData.mat -> a cell array with the raw data from the
% photomultiplier tube organized by row.

clear; close all; clc;

% State machine state definitions
INITIALIZE = 100;
HOMING = 110;
ROWSCAN = 201;
ROWRETURN = 210;
NEXTROW = 220;
END = 990;
STOP = 999;

% DAQ Setup
daqreset();
dq = daq("ni"); % Initialize a DataAcquisition interface object for an NI device
dq.Rate = 250e3;         % Set rate [Hz] - 2e6 with OLDHAM5 and 250e3 with OLDHAM3
% dqID = "PCIE6374_BNC"; % (OLDHAM5 Computer)
dqID = "Dev1";           % (OLDHAM 5 Computer Alternative)
% dqID = "PCI6221_bnc";  % (OLDHAM3 Computer)
ainPin = "ai0";                % Photomultiplier tube input pin
limswitchPin = "port0/line7";  % Limit switch input pin
xpin = "ao1";                  % Voltage control pin for x axis (channel B on KIM101)
ypin = "ao0";                  % Voltage control pin for y axis (channel A on KIM101)


in1 = addinput(dq, dqID, ainPin, "Voltage");             % Create input channel that we read data from
varName = dqID + "_" + ainPin;                           % Assemble variable name of input for convenient table indexing
outx = addoutput(dq, dqID, xpin, "Voltage");             % Output channel for x axis.
outy = addoutput(dq, dqID, ypin, "Voltage");             % Output channel for y axis.
limswitch = addinput(dq, dqID, limswitchPin, "Digital"); % Output channel for limit switch (digital)

% Prime controller (set voltages to 0V for 12 seconds)
% Set initial voltages to 0V for x and y axes
write(dq, [0, 0]);
% fprintf("Priming controller: 12 seconds...\n");
% pause(12); % Wait for 12 seconds


% TODO: Figure out why the hell we need to preload exactly 125000 datapoints.
% Write zero to the output pins for 12 seconds to prime piezo
% controller (as per KIM101 documentation).            
preload(dq, zeros(125000, 2));
start(dq, "repeatoutput");

% ------------------- Begin control loop & state machine ------------------
state = INITIALIZE; % Assign INITIALIZE state
init_time = tic; % Begin INITIALIZE timer
fprintf("State updated: INITIALIZE\n");
while state ~= STOP
    pause(0.0000001); % Infinitesimal pause to avoid loop binding
    switch state
        case INITIALIZE
            % Write zero to the output pins for 12 seconds to prime piezo
            % controller (as per KIM101 documentation).
            if toc(init_time) > 1 % TODO: Wait 12 seconds before starting homing
                init_time = toc(init_time); % Stop INITIALIZATION state stopwatch
                
                state = HOMING;    % Advance state to HOMING
                homing_time = tic; % Begin HOMING state stopwatch
                fprintf("State updated: HOMING\n");
                % Begin HOMING setup, the following code runs only once.
                % assign 1V to both control pins. The line below can be
                % used to stop and reassign new outputs to daq as required.
                stop(dq); flush(dq); preload(dq, ones(125000, 2)); start(dq, "repeatoutput");
                pause(1)
                % Initialize the data acumulator
                accu_data = read(dq, "all");
                
                % Next part of homing loop continues in the respective case statement
            end
        case HOMING
            new_data = read(dq, "all");
            accu_data = [accu_data; new_data];
            limswitchState = accu_data.(dqID + "_" + limswitchPin)(end);
            if limswitchState == 1
                homing_time = toc(homing_time); % Stop HOMING state stopwatch
                state = END; % Advance state to ROWSCAN
                fprintf("State updated: END\n");
            end
        case ROWSCAN

        case ROWRETURN

        case NEXTROW

        case END
            % Stop DAQ
            stop(dq); flush(dq); write(dq, [0,0]);
            state = STOP; % No state other than END should assign STOP or the code will error (by design).
            fprintf("State updated: STOP\n");
        otherwise
            error("Entered STOP prematurely or invalid state!");
    end
end
fprintf("Master loop exited.\n");
% -------------------- End control loop & state machine -------------------

stop(dq);
flush(dq);

fprintf("Program Completed.\n");

