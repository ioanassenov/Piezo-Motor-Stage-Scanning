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
TOTALROWS = 10;  % Quantity of rows to scan (must be at least 1)
INCREMENT = 20; % [steps] define distance moved between rows

HOMING_SPEED = -0.5;       % Valid values: [-1, 1]
FORWARD_SCAN_SPEED = 0.5;  % Valid values: [-1, 1]
REVERSE_SCAN_SPEED = -0.8; % Valid values: [-1, 1]
INIT_HOLD_TIME = 0;       % [s] Hold duration for controller to initialize (12s required on first run)
% -------------------------------------------------------------------------

% Control program
% State machine state definitions. State code numbers are arbitrary.
INITIALIZE = 100;
HOMING = 110;
ROWSCAN = 201;
ROWRETURN = 210;
NEXTROW = 220;
END = 990;
STOP = 999;
DEBUG = -100;

% Constants definition;
global MAX_CTRL_VOLTAGE VOLTS_TO_STEPS;
MAX_CTRL_VOLTAGE = 10;     % [Volts] Max input voltage for piezo controller
VOLTS_TO_STEPS = 67;       % [steps/s/V] Somewhat accurate around 20 step movements

% Initialize empty image data cell array
rawData = cell(TOTALROWS, 1);

% --------------------------- BEGIN DAQ SETUP -----------------------------
daqreset();
dq = daq("ni"); % Initialize a DataAcquisition interface object for an NI device
dq.Rate = 250e3;         % Set rate [Hz] - 2e6 with OLDHAM5 and 250e3 with OLDHAM3
% dqID = "PCIE6374_BNC"; % (OLDHAM5 Computer)
dqID = "Dev1";           % (OLDHAM 5 Computer Alternative)
% dqID = "PCI6221_bnc";  % (OLDHAM3 Computer)
ainPin = "ai0";                % Photomultiplier tube input (data) pin
limswitchPin = "port0/line7";  % Limit switch input pin
xPin = "ao0";                  % Voltage control pin for x axis (channel A on KIM101)
yPin = "ao1";                  % Voltage control pin for y axis (channel B on KIM101)
in1 = addinput(dq, dqID, ainPin, "Voltage");             % Create data input channel
varName = dqID + "_" + ainPin;                           % Assemble variable name of input for convenient table indexing
outx = addoutput(dq, dqID, xPin, "Voltage");             % Output channel for x axis.
outy = addoutput(dq, dqID, yPin, "Voltage");             % Output channel for y axis.
limswitch = addinput(dq, dqID, limswitchPin, "Digital"); % Output channel for limit switch (digital)
% ---------------------------- END DAQ SETUP ------------------------------

% --------------------------- BEGIN CONTROL LOOP --------------------------
try
    state = INITIALIZE; % Assign INITIALIZE state
    init_time = tic; fprintf("Initializing controller.\n"); % Begin INITIALIZE stopwatch
    totalscan_time = tic; % Begin master scan stopwatch
    fprintf("Commencing %.1f second hold for controller initialization.\n", INIT_HOLD_TIME);
    
    while state ~= STOP
        pause(100e-9); % Infinitesimal pause to avoid loop binding (could be made smaller?)
        switch state
            case INITIALIZE
                % Write zero to the output pins for 12 seconds to prime piezo
                % controller (as per KIM101 documentation).
                write(dq, [0,0]);
                if toc(init_time) > INIT_HOLD_TIME
                    fprintf("Initialization hold completed, beginning homing.\n");
                    % init_time = toc(init_time); % Stop INITIALIZATION state stopwatch
                    state = HOMING; % homing_time = tic; fprintf("[DEBUG] State updated: HOMING\n");
                    xMove(dq, HOMING_SPEED);
                    pause(0.1); % Small pause for data to accumulate
                    buffer = read(dq, "all"); % Initialize the data buffer
                end

            case HOMING
                new_data = read(dq, "all");
                buffer = [buffer; new_data]; % Continuous data for limswitch detection
                limswitchState = buffer.(dqID + "_" + limswitchPin)(end);
                if limswitchState == 1
                    halt(dq);
                    % homing_time = toc(homing_time); % Stop HOMING state stopwatch
                    fprintf("Homing completed, beginning scan of %i rows.\n", TOTALROWS);
                    state = ROWSCAN; % rowscan_time = tic;
                    totalrow_time = tic; % Begin timer for total row scan duration
                    % fprintf("[DEBUG] State updated: ROWSCAN\n");
                    buffer = clearBuffer(buffer); % TODO: See if these lines are really necessary
                    currentRow = 1;
                    xMove(dq, FORWARD_SCAN_SPEED);
                    pause(1); % Give the stage some time to move off switch before resuming loop.
                end

            case ROWSCAN
                new_data = read(dq, "all");
                buffer = [buffer; new_data]; % Continuous data for limswitch detection and reflection data.
                limswitchState = buffer.(dqID + "_" + limswitchPin)(end);
                if limswitchState == 1
                    halt(dq);
                    rawData{currentRow} = buffer;
                    % rowscan_time = toc(rowscan_time); fprintf("[DEBUG] Completed scanning row in %d seconds.\n", rowscan_time);
                    state = ROWRETURN; % rowreturn_time = tic; fprintf("[DEBUG] State updated: ROWRETURN\n");
                    buffer = clearBuffer(buffer); % TODO: See if these lines are really necessary
                    xMove(dq, REVERSE_SCAN_SPEED);
                    pause(1); % Give the stage some time to move off switch before resuming loop.
                end

            case ROWRETURN
                new_data = read(dq, "all");
                buffer = [buffer; new_data]; % Continuous data for limswitch detection
                limswitchState = buffer.(dqID + "_" + limswitchPin)(end);
                if limswitchState == 1
                    halt(dq);
                    state = NEXTROW;
                    % rowreturn_time = toc(rowreturn_time); fprintf("[DEBUG] Completed row return in %d seconds.\n", rowreturn_time);
                    % fprintf("[DEBUG] State updated: NEXTROW\n");
                end

            case NEXTROW
                totalrow_time = toc(totalrow_time); % Stop total row stopwatch
                rows_remaining = TOTALROWS - currentRow;
                time_remaining = totalrow_time * rows_remaining;
                fprintf("Row %i/%i scanned in %.3f seconds. ~%im %is remaining.\n", currentRow, TOTALROWS, totalrow_time, floor(time_remaining/60), int16(mod(time_remaining, 60)));
                if currentRow ~= TOTALROWS
                    currentRow = currentRow + 1; % Advance row tracker
                    yMoveSteps(dq, INCREMENT); % Move the y stage for the next row
                    state = ROWSCAN; % rowscan_time = tic; fprintf("[DEBUG] State updated: ROWSCAN\n");
                    totalrow_time = tic;
                    xMove(dq, FORWARD_SCAN_SPEED);
                    pause(1); % Give the stages some time to move off switch before resuming loop.
                    buffer = clearBuffer(buffer);
                    continue;
                end
                fprintf("All rows scanned.\n");
                state = END;
                % fprintf("[DEBUG] State updated: END\n");

            case END
                halt(dq);
                state = STOP; % No state other than END should assign STOP or the code will error (by design).
                % fprintf("[DEBUG] State updated: STOP\n");
            
            case DEBUG
                % To enter the DEBUG case, assign the state manually.
                pause(1);
                fprintf("Entered DEBUG state.\n")
                yMoveSteps(dq, 20);
                halt(dq);
                state = END;

            otherwise
                error("Entered STOP prematurely or invalid state!");
        end
    end
    fprintf("Master loop exited.\n");
catch err
    halt(dq);
    fprintf("Error has caused the program to stop. Last program state: %i\n", state);
    rethrow(err);
end
% --------------------------- END CONTROL LOOP ----------------------------

% Display wrap up stats
totalscan_time = toc(totalscan_time);
fprintf("Program Completed.\n");
fprintf("Scanned %d row(s) in %d min %f sec.\n", currentRow, int16(totalscan_time/60), mod(totalscan_time, 60))

% Save scan file in current directory
t = datetime;
t.Format = 'yyyy-MM-dd''T''HHmm';
filename = strcat("scan",string(t),".mat");
save(filename, "rawData");
fprintf("Saved scan data to %s\n", filename);


% ----------------------- BEGIN FUNCTION DEFINITIONS ----------------------
function halt(dq)
% Stop, flush, and write 0 on DAQ to stop any stage movements.
    stop(dq); flush(dq); write(dq, [0,0]);
end

function xMove(dq,speed)
% Move x axis and run continous data acquisition simulatenously    
    global MAX_CTRL_VOLTAGE;
    if abs(speed) > 1
        error("Speed cannot be greater than 1 or less than -1.")
    end
    % Restart DAQ for continuous operation at requested speed.
    stop(dq); flush(dq);
    minValQ = 0.5*dq.Rate; % Minimum value of values required for "repeatoutput"
    % First column of signal controls the ao0 (xPin) and second column ao1 (yPin)
    signal = [speed.*MAX_CTRL_VOLTAGE.*ones(minValQ, 1), zeros(minValQ, 1)];
    preload(dq, signal);
    start(dq, "repeatoutput");
end

function yMoveSteps(dq, steps)
% Move y axis given number of steps (approximately)
    global MAX_CTRL_VOLTAGE VOLTS_TO_STEPS;
    % Volts to steps conversion factor is approximately accurate around 20 steps
    yVoltage = 1; % Command voltage fixed, pause duration varied.
    halt(dq);
    write(dq, [0, yVoltage]);
    % Pause to move the approximate number of steps.
    pause(steps*yVoltage/VOLTS_TO_STEPS);
    write(dq, [0,0]);
end

function buffer = clearBuffer(buffer)
% Clear the buffer while preserving variable types, names, and sample rate
    buffer_vartypes = buffer.Properties.VariableTypes;
    buffer_varnames = buffer.Properties.VariableNames;
    buffer_samplerate = buffer.Properties.SampleRate;
    buffer = timetable( ...
        Size = [0,width(buffer)], ...
        VariableTypes = buffer_vartypes, ...
        VariableNames = buffer_varnames, ...
        SampleRate = buffer_samplerate);
end
% ------------------------ END FUNCTION DEFINITIONS -----------------------
