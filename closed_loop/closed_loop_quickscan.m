% Title: Inertial Drive Stage 2 Dimensional Continuous Scan
% Filename: closed_loop_quickscan.m
% Author: Ioan Assenov
%
% Description: This file is used as a test to both move the stages and
% record data from the photomultiplier tube at the same time. It scans
% along a given width and height (in steps) while continuously collecting
% data.
%
% Program output: rawData.mat -> a cell array with the raw data from the
% photomultiplier tube organized by row.

clear; close all; clc;

dq = daq("ni");
addchannel(dq, "Dev1", "ai0");
addchannel(dq, "Dev1", "ai1");
dq.Rate = 100000;