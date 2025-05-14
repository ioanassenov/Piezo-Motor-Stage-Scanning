# Piezo Inertial Drive Stage Scanning Autosequences

This repository contains MATLAB code autosequences used to control the Piezoelectric Inertial Drive Stages
made by Thorlabs.

##### Repository File Structure
- `KIM101_GUIDE.m` This is the original code provided by Thorlabs to demonstrate MATLAB implementation of the API
- `IDS_Scanning.m` This file contains the main autosequence that scans across the surface of a stage in an XY configuration
- `testing.m`      A sandbox file for testing purposes
- `Documentation/` This directory has documentation PDFs from Thorlabs about the relevant components.

##### Dependencies
The code in this repo uses the .NET objects and methods defined in Thorlabs' Kinesis DLLs provided for free
available on their (website)[https://www.thorlabs.com/software_pages/ViewSoftwarePage.cfm?Code=Motion_Control&viewtab=0].
