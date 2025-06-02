# Piezo Inertial Drive Stage Scanning Autosequences

This repository contains MATLAB code autosequences used to control the
Piezoelectric Inertial Drive Stages made by Thorlabs.

## Notable Files
- `quick_scan.m` Scans a target in 2D and generates a raw data scan file.
- `data_processing.m` Used to process the output of the above script into an image.
- `testing_scripts/` Contains test scripts that can be used as guides on the libraries.


## Movement
<img src="/assets/stagedirections.png" alt="Stage directions diagram" width="500"/>

*Note that the xy coordinate system is inertial and is NOT fixed to the stage*

Movement of the stage is open-loop control when run without limit switches
or other sensors. With the default speed, the range of motion in the
forward direction is about `7200` steps. The range of motion in the reverse
direction is about `15400` steps. This value can change depending on the
step rate.

## Hysteresis
The piezoelectric inertial drive stages exhibit different behaviors moving 
backward and forward. Forward motion is more easily achieved by the
Thorlabs PD stages and thus when moving in reverse a larger cycle count is 
necessary to match an equal forward motion. This value can change depending
on load configuration. Therefore the appropriate movement step counts must
be updated in the autosequence.

## Dependencies & Resources
The code in this repo uses the .NET objects and methods defined in
Thorlabs' Kinesis DLLs provided for free available on their
[website](https://www.thorlabs.com/software_pages/ViewSoftwarePage.cfm?Code=Motion_Control&viewtab=0).
All required DLL files are included but Kinesis download might still be
necessary to install the KIM101 USB drivers. The **MATLAB Data Acquisition
Toolbox** is required for data collection.

Within the Kinesis installation directory (default is `C:\Program Files\Thorlabs\Kinesis`)
there are two compiled HTML help files available for assistance with using the APIs:
- `Thorlabs.MotionControl.DotNet_API.chm` For help with the .NET API
- `Thorlabs.MotionControl.C_API.chm` For help with the C API
