% Title: Data Processing Suite Script
% Filename: data_processing.m
% Author: Ioan Assenov
%
% Description: This script contains several useful functions for processing
% the raw image data once it has been collected by one of the *scan.m
% scripts. The sections in this file are meant to be run sequentially using
% the run section function of MATLAB (ctrl+enter)

%% 1) Read file
clear; clc;
fprintf("1) Reading scan data...\n")
filename = "scan2025-05-30T1543.mat";
filepath = fullfile("completed_scans", filename);
load(filepath);
fprintf("|\tSuccessfully loaded scan data: %s\n", filepath);


%% 2) Integrity check
rowLengths = cellfun(@length, rawData);
modeLength = mode(rowLengths); % Use mode to determine healthy length
susRows = find(rowLengths ~= modeLength);
fprintf("\n2) Performing integrity check on %d rows...\n", length(rawData));
fprintf("|\tExpected row length is %d as determined by mode\n", modeLength);
fprintf("|\tFound %d unhealthy rows\n", length(susRows));

% Scan through suspicious rows to determine what is wrong with them
for item=1:length(susRows)
    if rowLengths(susRows(item)) == 0
        fprintf("|\t")
        warning("Row %d has no data", susRows(item));
        continue;
    end
    if rowLengths(susRows(item)) ~= modeLength
        fprintf("|\t")
        warning("Row %d has an unexpected length of %d, expected %d.", susRows(item), rowLengths(susRows(item)), modeLength);
        continue
    end
end
% Display message if all rows are healthy
if isempty(susRows)
    fprintf("|\tData is healthy!\n");
end


%% 3A) Clean up data - Delete unhealthy rows (after integrity check)
rawData(susRows) = [];
fprintf("\n3A) Deleted %d unhealthy rows!\n", length(susRows));
fprintf("|\tData now has %d rows.\n", length(rawData));
susRows = [];

%% 3B) Clean up data - Replace unhealthy rows with NaN (after integrity check)
rawData(susRows) = {nan(modeLength, 1)};
fprintf("\n3B) Filled %d unhealthy rows with NaN!\n", length(susRows));
fprintf("|\tData now has %d rows.\n", length(rawData));
susRows = [];

%% 3C) Clean up data - Truncate rows with excess entries (after integrity check)
rawData(susRows) = cellfun(@(x) x(1:modeLength), rawData(susRows), "UniformOutput", false);
fprintf("\n3C) Truncated %d unhealthy rows to %d columns!\n", length(susRows), modeLength);
fprintf("|\tData now has %d rows.\n", length(rawData));
susRows = [];


%% 4) Convert data to matrix
fprintf("\n4) Internally transposing rawData rows for matrix conversion...\n")
% Transpose each individual row (since they are read as column vectors)
rawDataT = cellfun(@transpose, rawData, "UniformOutput", false);

rawDataMat = cell2mat(rawDataT);
fprintf("|\tRaw data cell array converted to matrix with %d rows and %d columns\n", ...
    size(rawDataMat, 1), size(rawDataMat, 2));


%% 5A) Row-wise column average downsampling
% Downsample the image by averaging groups of columns
fprintf("\n5A) Using row-wise averaging downsampling for image generation\n");
% Specify number of (horizontal) pixels desired
% pixelCount = length(rawData)
pixelCount = 5000;
pixelSize = int32(modeLength/pixelCount); % Truncate to integer

% Downsample the image row-wise by averaging
imageData = blockproc(rawDataMat, [1, pixelSize], @(x) mean(x.data));

% Rotate the data for correct image orientation
imageData = rot90(imageData, 2);

fprintf("|\tNew imageData processed with size %dx%d\n", size(imageData, 1), size(imageData, 2));

%% 5B) Row-wise column skip downsampling
% Downsample the image by skipping columns
fprintf("\n5B) Using row-wise column skip downsampling for image generation\n");
pixelCount = 5000;
pixelSize = int32(modeLength/pixelCount); % Truncate to integer

% Downsample the image row-wise by skipping
imageData = rawDataMat(:, 1:pixelSize:end);

% Rotate the data for correct image orientation
imageData = rot90(imageData, 2);

fprintf("|\tNew imageData processed with size %dx%d\n", size(imageData, 1), size(imageData, 2));


%% 6) Create heatmap image
fprintf("\n6) Generating heatmap\n");
figure(Name=string(datetime));
h = heatmap(imageData);

% Heatmap style options
h.GridVisible = "off";
h.ColorbarVisible = "off";
h.XDisplayLabels = nan(size(h.XDisplayData));
h.YDisplayLabels = nan(size(h.YDisplayData));