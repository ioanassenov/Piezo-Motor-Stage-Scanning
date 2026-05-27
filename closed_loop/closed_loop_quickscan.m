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

% --------------------------- Scan parameters -----------------------------
INCREMENT = 20;    % [steps] define distance moved between rows
ROWS = 1;          % Quantity of rows to scan (must be at least 1)
ENDXPOS   = 10800; % [steps] define the final X value of the rows
% -------------------------------------------------------------------------

% Control program
% State machine state definitions
INITIALIZE = 100;
HOMING = 110;
ROWSCAN = 201;
ROWRETURN = 210;
NEXTROW = 220;
END = 990;
STOP = 999;

% Global Constants definition;
global MAX_CTRL_VOLTAGE;
MAX_CTRL_VOLTAGE = 10;

% --------------------------- BEGIN DAQ SETUP -----------------------------
daqreset();
dq = daq("ni"); % Initialize a DataAcquisition interface object for an NI device
dq.Rate = 250e3;         % Set rate [Hz] - 2e6 with OLDHAM5 and 250e3 with OLDHAM3
% dqID = "PCIE6374_BNC"; % (OLDHAM5 Computer)
dqID = "Dev1";           % (OLDHAM 5 Computer Alternative)
% dqID = "PCI6221_bnc";  % (OLDHAM3 Computer)
ainPin = "ai0";                % Photomultiplier tube input pin
limswitchPin = "port0/line7";  % Limit switch input pin
xPin = "ao1";                  % Voltage control pin for x axis (channel B on KIM101)
yPin = "ao0";                  % Voltage control pin for y axis (channel A on KIM101)
in1 = addinput(dq, dqID, ainPin, "Voltage");             % Create input channel that we read data from
varName = dqID + "_" + ainPin;                           % Assemble variable name of input for convenient table indexing
outx = addoutput(dq, dqID, xPin, "Voltage");             % Output channel for x axis.
outy = addoutput(dq, dqID, yPin, "Voltage");             % Output channel for y axis.
limswitch = addinput(dq, dqID, limswitchPin, "Digital"); % Output channel for limit switch (digital)
% ---------------------------- END DAQ SETUP ------------------------------

% --------------------------- BEGIN CONTROL LOOP --------------------------
state = INITIALIZE; % Assign INITIALIZE state
init_time = tic; % Begin INITIALIZE timer
fprintf("State updated: INITIALIZE\n");
while state ~= STOP
    pause(0.0000001); % Infinitesimal pause to avoid loop binding
    switch state
        case INITIALIZE
            % Write zero to the output pins for 12 seconds to prime piezo
            % controller (as per KIM101 documentation).
            write(dq, [0,0]);
            if toc(init_time) > 1 % TODO: Wait 12 seconds before starting homing
                init_time = toc(init_time); % Stop INITIALIZATION state stopwatch
                state = HOMING;    % Advance state to HOMING
                homing_time = tic; % Begin HOMING state stopwatch
                fprintf("State updated: HOMING\n");
                % Begin HOMING setup, the following code runs only once.
                movex(dq, 0.12);
                pause(0.1)
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
                state = ROWSCAN; % Advance state to ROWSCAN
                rowscan_time = tic;
                fprintf("State updated: ROWSCAN\n");
            end
        case ROWSCAN
            state = END;
        case ROWRETURN

        case NEXTROW

        case END
            halt(dq);
            state = STOP; % No state other than END should assign STOP or the code will error (by design).
            fprintf("State updated: STOP\n");
        otherwise
            error("Entered STOP prematurely or invalid state!");
    end
end
fprintf("Master loop exited.\n");
% --------------------------- END CONTROL LOOP ----------------------------

fprintf("Program Completed.\n");

% ----------------------- BEGIN FUNCTION DEFINITIONS ----------------------
function halt(dq)
    % Stop, flush, and write 0 on DAQ to stop any stage movements.
    stop(dq); flush(dq); write(dq, [0,0]);
end

function movex(dq,speed)
    global MAX_CTRL_VOLTAGE;
    if abs(speed) > 1
        error("Speed cannot be greater than 1 or less than -1.")
    end
    % Restart DAQ for continuous operation at requested speed.
    % Speed specified as value from -1 to 1.
    stop(dq); flush(dq);
    minValQ = 0.5*dq.Rate; % Minimum value of values required for "repeatoutput"
    % First column of signal controls the ao1 (xPin) and second column ao0 (yPin)
    signal = [speed.*MAX_CTRL_VOLTAGE.*ones(minValQ, 1), zeros(minValQ, 1)];
    preload(dq, signal);
    start(dq, "repeatoutput");
end
% ------------------------ END FUNCTION DEFINITIONS -----------------------
