% Title: Inertial Drive Stage 2 Dimensional Continuous Scan with Sensing
% Filename: isolated_closed_loop_quickscan.m
% Author: Ioan Assenov
%
% Description: This file is used to both move the stages and record data
% from the photomultiplier tube at the same time. It scans along a given
% width and height (in steps) while continuously collecting data. This
% script controls the THORLABS stages AND collects reflection data using
% solely the NI DAQ. This script attempts to achieve a faster control rate
% by separating the inputs and outputs into separate task objects: (dqIn, dqOut)
% 
%
% Program output: rawData.mat -> a cell array with the raw data from the
% photomultiplier tube organized by row.

clear; close all; clc;

% --------------------------- Scan parameters -----------------------------
TOTALROWS = 50;  % Quantity of rows to scan (must be at least 1)
INCREMENT = 50; % [steps] define distance moved between rows (approximate)

HOMING_SPEED = -0.5;      % Valid values: [-1, 1]
FORWARD_SCAN_SPEED = 0.5; % Valid values: [-1, 1]
REVERSE_SCAN_SPEED = -1;  % Valid values: [-1, 1]
INIT_HOLD_TIME = 12;       % [s] Hold duration for controller to initialize (12s required on first run)
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
global MAX_CTRL_VOLTAGE VOLTS_TO_STEPS Y_CTRL_VOLTAGE dqOut dqIn;
MAX_CTRL_VOLTAGE = 10; % [Volts] Max input voltage for piezo controller
VOLTS_TO_STEPS = 76;   % [steps/s/V] Somewhat accurate around 20 step movements
Y_CTRL_VOLTAGE = 1;    % [Volts] Control voltage for Y stage movements; (+) step counts move up

% Initialize empty image data cell array
rawData = cell(TOTALROWS, 1);

% --------------------------- BEGIN DAQ SETUP -----------------------------
daqreset();
dqOut = daq("ni");  % Initialize a DataAcquisition interface object for the OUTPUTS
dqIn = daq("ni");   % Initialize a DataAcquisition interface object for the INPUTS
dq = [dqOut, dqIn]; % Put in a vector for convenient accessing.

dqIn.Rate = 1e6;         % Set rate [Hz] - 2e6 with OLDHAM5 and 250e3 with OLDHAM3
% dqID = "PCIE6374_BNC"; % (OLDHAM5 Computer)
dqID = "Dev1";           % (OLDHAM 5 Computer Alternative)
% dqID = "PCI6221_bnc";  % (OLDHAM3 Computer)

ainPin = "ai0";                % Photomultiplier tube input (data) pin
limswitchPin = "port0/line7";  % Limit switch input pin
xPin = "ao0";                  % Voltage control pin for x axis (channel A on KIM101)
yPin = "ao1";                  % Voltage control pin for y axis (channel B on KIM101)

in1 = addinput(dqIn, dqID, ainPin, "Voltage");             % Create data input channel
limswitch = addinput(dqIn, dqID, limswitchPin, "Digital");  % Input channel for limit switch (digital)

outx = addoutput(dqOut, dqID, xPin, "Voltage");             % Output channel for x axis.
outy = addoutput(dqOut, dqID, yPin, "Voltage");             % Output channel for y axis.
% ---------------------------- END DAQ SETUP ------------------------------

% --------------------------- BEGIN CONTROL LOOP --------------------------
try
    state = INITIALIZE; % Assign INITIALIZE state (Assign DEBUG to enter debug case)
    init_time = tic; % Begin INITIALIZE stopwatch
    fprintf("Commencing %.1f second hold for controller initialization.\n", INIT_HOLD_TIME);
    
    while state ~= STOP
        pause(10e-9); % Infinitesimal pause to avoid loop binding
        switch state
            case INITIALIZE
                % Write zero to the output pins for 12 seconds to prime piezo
                % controller (as per KIM101 documentation).
                stopMove();
                if toc(init_time) > INIT_HOLD_TIME
                    fprintf("Initialization hold completed, beginning homing.\n");
                    % init_time = toc(init_time); % Stop INITIALIZATION state stopwatch
                    state = HOMING; homing_time = tic;
                    startRead(); % Start read for limit switch state during homing.
                    moveX(HOMING_SPEED);
                    buffer = [0, 0]; % Initialize the data buffer
                end

            case HOMING
                new_data = read(dqIn, "all", OutputFormat="Matrix");
                buffer = [buffer; new_data]; % Continuous data for limswitch detection
                limswitchState = buffer(end, 2);
                if limswitchState == 1
                    stopMove();
                    fprintf("Homing completed in %.2f seconds, beginning scan of %i rows.\n", toc(homing_time), TOTALROWS);
                    totalscan_time = tic; % Begin master scan stopwatch
                    state = ROWSCAN; % rowscan_time = tic;
                    totalrow_time = tic; % Begin timer for total row scan duration
                    % fprintf("[DEBUG] State updated: ROWSCAN\n");
                    currentRow = 1; % Initialize row counter
                    buffer = [];
                    startRead();
                    moveX(FORWARD_SCAN_SPEED);
                    pause(1); % Give the stage some time to move off switch before resuming loop.
                end

            case ROWSCAN
                new_data = read(dqIn, "all", OutputFormat="Matrix");
                buffer = [buffer; new_data]; % Continuous data for limswitch detection and reflection data.
                limswitchState = buffer(end, 2);
                if limswitchState == 1
                    stopMove();
                    rawData{currentRow} = buffer;                    
                    state = ROWRETURN;
                    buffer = [];
                    moveX(REVERSE_SCAN_SPEED);
                    pause(1); % Give the stage some time to move off switch before resuming loop.
                end

            case ROWRETURN
                new_data = read(dqIn, "all", OutputFormat="Matrix");
                buffer = [buffer; new_data]; % Continuous data for limswitch detection
                limswitchState = buffer(end, 2);
                if limswitchState == 1
                    stopMove();
                    state = NEXTROW;
                end

            case NEXTROW
                totalrow_time = toc(totalrow_time); % Stop total row stopwatch
                rows_remaining = TOTALROWS - currentRow;
                time_remaining = totalrow_time * rows_remaining;
                fprintf("Row %i/%i scanned in %.3f seconds. ~%im %is remaining.\n", currentRow, TOTALROWS, totalrow_time, floor(time_remaining/60), int16(mod(time_remaining, 60)));
                if currentRow ~= TOTALROWS
                    currentRow = currentRow + 1; % Advance row tracker
                    moveYSteps(INCREMENT); % Move the y stage for the next row
                    state = ROWSCAN;
                    totalrow_time = tic;
                    buffer = []; % Clear buffer for new row data
                    startRead(); % Flush and restart DAQ for new row data.
                    moveX(FORWARD_SCAN_SPEED);
                    pause(1); % Give the stages some time to move off switch before resuming loop.
                    continue;
                end
                fprintf("All rows scanned.\n");
                state = END;

            case END
                stopMove();
                flush(dqIn); stop(dqIn);% Flush and stop data collection DAQ object.
                state = STOP; % No state other than END should assign STOP or the code will error (by design).
                % Display wrap up stats
                totalscan_time = toc(totalscan_time);
                fprintf("Scanned %d row(s) in %d min %.3f sec.\n", currentRow, int16(totalscan_time/60), mod(totalscan_time, 60))
            
            case DEBUG
                % To enter the DEBUG case, assign the state manually.
                fprintf("Entered DEBUG state.\n")
                pause(INIT_HOLD_TIME);
                fprintf("Hold completed, moving Y.\n")
                moveYSteps(50);
                fprintf("Y move completed, exiting.\n")
                stopMove();
                state = STOP;

            otherwise
                error("Entered STOP prematurely or invalid state!");
        end
    end
catch err
    stopMove();
    fprintf("Error has caused the program to stop. Last program state: %i\n", state);
    rethrow(err);
end
% --------------------------- END CONTROL LOOP ----------------------------

% Save scan file in current directory
t = datetime;
t.Format = 'yyyy-MM-dd''T''HHmm';
warning('off', 'MATLAB:MKDIR:DirectoryExists'); mkdir scans % Make scans directory if not exist; suppress exist warning.
filename = strcat("scans/","scan",string(t),".mat");
save(filename, "rawData");
fprintf("Saved scan data to %s\n", filename);


% ----------------------- BEGIN FUNCTION DEFINITIONS ----------------------
function stopMove()
% Write 0 on DAQ to stop any stage movements.
    global dqOut;
    write(dqOut, [0,0]);
end

function moveX(speed)
    global MAX_CTRL_VOLTAGE dqOut;
    if abs(speed) > 1 % Input validation
        error("Speed cannot be greater than 1 or less than -1.");
    end
    % First column of signal controls the ao0 (xPin) and second column ao1 (yPin)
    write(dqOut, [speed.*MAX_CTRL_VOLTAGE, 0])
end

function moveYSteps(steps)
% Move y axis given number of steps (approximately)
    global MAX_CTRL_VOLTAGE VOLTS_TO_STEPS Y_CTRL_VOLTAGE dqOut;
    if abs(Y_CTRL_VOLTAGE) > abs(MAX_CTRL_VOLTAGE)
        error("Y_CTRL_VOLTAGE cannot exceed MAX_CTRL_VOLTAGE.");
    end
    % Volts to steps conversion factor is not exact.
    write(dqOut, [0, sign(steps)*Y_CTRL_VOLTAGE]);
    % Pause to move the approximate number of steps.
    pause(abs(steps*Y_CTRL_VOLTAGE/VOLTS_TO_STEPS)); % Absolute value accounts for (-) voltages
    write(dqOut, [0,0]);
end

function startRead()
% Stop, flush, and then restart DAQ continuous input.
    global dqIn;
    stop(dqIn); flush(dqIn); start(dqIn, "continuous");
end
% ------------------------ END FUNCTION DEFINITIONS -----------------------
