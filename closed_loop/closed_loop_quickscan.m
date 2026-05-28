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
TOTALROWS = 2;          % Quantity of rows to scan (must be at least 1)
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

% Initialize empty image data cell array
rawData = cell(TOTALROWS, 1);

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
try
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
                    xMove(dq, -0.12); % This function also begins continuous data acquisition.
                    pause(0.1)
                    % Initialize the data buffer
                    buffer = read(dq, "all");
                    % Next part of homing loop continues in the respective case statement
                end
            case HOMING
                new_data = read(dq, "all");
                buffer = [buffer; new_data];
                limswitchState = buffer.(dqID + "_" + limswitchPin)(end);
                if limswitchState == 1
                    halt(dq);
                    homing_time = toc(homing_time); % Stop HOMING state stopwatch
                    % Advance state to ROWSCAN
                    state = ROWSCAN;
                    rowscan_time = tic;
                    fprintf("State updated: ROWSCAN\n");
                    buffer = clearBuffer(buffer);
                    currentRow = 1;
                    xMove(dq, 0.5);
                    pause(1); % Give the stages some time to move off switch before resuming loop.
                end

            case ROWSCAN
                new_data = read(dq, "all");
                buffer = [buffer; new_data];
                limswitchState = buffer.(dqID + "_" + limswitchPin)(end);
                if limswitchState == 1
                    halt(dq);
                    rawData{currentRow} = buffer;
                    rowscan_time = toc(rowscan_time);
                    fprintf("Completed scanning row in %d seconds.\n", rowscan_time);
                    % Advance state to ROWRETURN
                    state = ROWRETURN;
                    rowreturn_time = tic;
                    fprintf("State updated: ROWRETURN\n");
                    buffer = clearBuffer(buffer);
                    xMove(dq, -0.5);
                    pause(1);
                end

            case ROWRETURN
                new_data = read(dq, "all");
                buffer = [buffer; new_data];
                limswitchState = buffer.(dqID + "_" + limswitchPin)(end);
                if limswitchState == 1
                    halt(dq);
                    rowreturn_time = toc(rowreturn_time);
                    fprintf("Completed row return in %d seconds.\n", rowreturn_time);
                    % If this was not last row, keep scanning
                    % Advance state to ROWRETURN
                    state = NEXTROW;
                    rowreturn_time = tic;
                    fprintf("State updated: NEXTROW\n");
                end

            case NEXTROW
                if currentRow ~= TOTALROWS
                    totalrow_time = rowscan_time + rowreturn_time;
                    fprintf("Row %i scanned, %i rows remaining.\n", currentRow, TOTALROWS-currentRow);
                    currentRow = currentRow + 1; % Advance row tracker
                    state = ROWSCAN;
                    rowscan_time = tic;
                    fprintf("State updated: ROWSCAN\n");
                    xMove(dq, 0.5);
                    pause(1); % Give the stages some time to move off switch before resuming loop.
                    buffer = clearBuffer(buffer);
                    continue;
                end
                fprintf("All rows scanned.\n");
                state = END;
                fprintf("State updated: END\n");

            case END
                halt(dq);
                state = STOP; % No state other than END should assign STOP or the code will error (by design).
                fprintf("State updated: STOP\n");
            otherwise
                error("Entered STOP prematurely or invalid state!");
        end
    end
    fprintf("Master loop exited.\n");
catch err
    disp("Error has caused the program to stop, disconnecting...")
    halt(dq);
    rethrow(err);
end
% --------------------------- END CONTROL LOOP ----------------------------

fprintf("Program Completed.\n");

% ----------------------- BEGIN FUNCTION DEFINITIONS ----------------------
function halt(dq)
    % Stop, flush, and write 0 on DAQ to stop any stage movements.
    stop(dq); flush(dq); write(dq, [0,0]);
end

function xMove(dq,speed)
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

function yMoveStep(dq, steps)
    global MAX_CTRL_VOLTAGE;
    % TODO: Implement a stepped y movement for row incrementing. This
    % should move the y stage a programmable amount of steps every single
    % time. It would require understanding how fast in steps/second the
    % stages move at any given voltage. The code would take the form:
    minValQ = 0.5*dq.Rate; % Minimum value of values required for "repeatoutput"
    % speed = some arbitrary value in Volts
    write(dq, [speed, 0]);
    %pause(steps*speed/[conversion factor from V to steps/s])
    write(dq, [0,0]);
end

function buffer = clearBuffer(buffer)
    buffer_width = width(buffer);
    buffer_vartypes = buffer.Properties.VariableTypes;
    buffer_varnames = buffer.Properties.VariableNames;
    buffer_samplerate = buffer.Properties.SampleRate;
    buffer = timetable( ...
        Size = [0,size(buffer, 2)], ...
        VariableTypes = buffer_vartypes, ...
        VariableNames = buffer_varnames, ...
        SampleRate = buffer_samplerate);
end
% ------------------------ END FUNCTION DEFINITIONS -----------------------
