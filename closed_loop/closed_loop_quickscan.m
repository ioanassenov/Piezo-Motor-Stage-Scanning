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

% DAQ Setup
dq = daq("ni"); % Initialize a DataAcquisition interface object for an NI device
dq.Rate = 250e3;         % Set rate [Hz] - 2e6 with OLDHAM5 and 250e3 with OLDHAM3
% dqID = "PCIE6374_BNC"; % (OLDHAM5 Computer)
dqID = "Dev1";           % (OLDHAM 5 Computer Alternative)
% dqID = "PCI6221_bnc";  % (OLDHAM3 Computer)
ainPin = "ai0";                % Photomultiplier tube input pin
limswitchPin = "port0/line0";  % Limit switch input pin
xpin = "ao1";                  % Voltage control pin for x axis (channel B on KIM101)
ypin = "ao0";                  % Voltage control pin for y axis (channel A on KIM101)


in1 = addinput(dq, dqID, ainPin, "Voltage");             % Create input channel that we read data from
varName = dqID + "_" + ainPin;                           % Assemble variable name of input for convenient table indexing
outx = addoutput(dq, dqID, xpin, "Voltage");             % Output channel for x axis.
outy = addoutput(dq, dqID, ypin, "Voltage");             % Output channel for y axis.
limswitch = addinput(dq, dqID, limswitchPin, "Digital"); % Output channel for limit switch (digital)

fs = dq.Rate;
dq.ScansAvailableFcnCount = fs;
dq.ScansAvailableFcn = @(dq, evt) stateEval(dq, evt);

function stateEval(dq, evt)
    fprintf("Scans met!\n");
    read_data = dq.read("all");
    accu_data = [accu_data; read_data]; % Append new data from last read to accumulator
    limswitchState = 0;
    fprintf("State of digital pin: %i\n", limswitchState)
end


% Prime controller (set voltages to 0V for 12 seconds)
% Set initial voltages to 0V for x and y axes
write(dq, [0, 0]);
fprintf("Priming controller: 1 seconds...\n");
pause(0.01); % Wait for 12 seconds

% Move x axis for 1 second at 1V;
fprintf("Beginning continuous acquisition for 12 seconds!\n");
preload(dq, zeros(fs, 2)); % Preload 0 volts into the output pins
start(dq, "repeatoutput");

while dq.Running
    pause(0.5)
    fprintf("Scans acquired = %d\n", dq.NumScansAcquired)
    if dq.NumScansAcquired > fs*12
        data = dq.read("all");
        dq.stop();
    end
end
fprintf("Acquisition stopped after %d scans\n", dq.NumScansAcquired);

dq.stop();
dq.flush();
fprintf("Program Completed.\n");