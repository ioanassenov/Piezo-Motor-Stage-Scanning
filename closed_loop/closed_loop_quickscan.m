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
dq = daq("ni"); % Initialize a DataAcquisition interface object for an NI device
dq.Rate = 250e3;         % Set rate [Hz] - 2e6 with OLDHAM5 and 250e3 with OLDHAM3
% dqID = "PCIE6374_BNC"; % (OLDHAM5 Computer)
% dqID = "Dev1";           % (OLDHAM 5 Computer Alternative)
dqID = "PCI6221_bnc";  % (OLDHAM3 Computer)
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

% Data collection
fprintf("Beginning continuous acquisition for 12 seconds!\n");
preload(dq, zeros(125000, 2)); % Preload 0 volts into the output pins
start(dq, "repeatoutput");

% Initialize the data acumulator
accu_data = read(dq, "all");

% Begin state machine
state = INITIALIZE; % Assign initialization state
tic;
while state ~= END
    pause(0.0000001); % Infinitesimal pause to avoid loop binding
    switch state
        case INITIALIZE
            new_data = read(dq, "all");
            accu_data = [accu_data; new_data];
            if toc > 2 &&  accu_data.("PCI6221_bnc_port0/line7")(end) == 1
                state=END;
            end
        case HOMING
        case ROWSCAN
        case ROWRETURN
        case NEXTROW
        case END
            fprintf("Read high on limit switch! Stopping...");
            state = STOP;
        otherwise
            error("Entered invalid state!");
    end
end

fprintf("Acquisition stopped after %d scans.\n", dq.NumScansAcquired);

stop(dq);
flush(dq);

fprintf("Program Completed.\n");

