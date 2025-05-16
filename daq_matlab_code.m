clear all
close all

%% DAQ initialization

%This function finds all the DAQ system by National  Instruments (NI)
d = daqlist("ni")

%This function tells you some brief information of the deck. Including the
%number of inputs and outputs, maximum sampling frequency ......
deviceinfo1 = d(1,"DeviceInfo")

% This function creates a DataAcquisition interface object for a National Instruments device
dq = daq("ni");

%Specify the sampling frequency. If you enter a number higher than the
%maximum sampling freqeuncy for the deck, the maximum sampling frequency
%will be used instead. 
dq.Rate = 2e4;

%% I/O Specification

%Below is the functions that setup the inputs and outputs for the deck.
%Depending on the computer you are using, the name of the deck is
%different. For "OLDHAM3", the name is 'PCI6221_bnc'. For "OLDHAM5", the
%name is 'PCIE6374_bnc'. You can double check with the "daqlist" function
%in the previous section. 

%For both two decks, they have 4 input analog channels with voltage input
%from -10 Volts to 10 Volt. Voltages beyond this range will be chopped.
%They both have two outputs with the output range from -10 Volts to 10
%Volts. 

ai0 = addinput(dq,'PCI6221_bnc','ai3',"Voltage");
ai1 = addinput(dq,'PCI6221_bnc','ai1',"Voltage");
%ai2 = addinput(dq,'PCI6221_bnc','ai2',"Voltage");
ao0 = addoutput(dq,'PCI6221_bnc','ao1',"Voltage");

%% Data Collection

%If you have both input and output channels specified, use the function
%"readwrite". If you only have input channels, use function "read" instead.
%Below shows an example to output a 1 Hz sine wave while reading from the
%two input channels. 


%data = read(dq,1000,"OutputFormat","Matrix");
T = 10; t = 0:1/dq.Rate:T;
V = sin(2*pi*t);
data = readwrite(dq,V');
%data = read(dq,seconds(1),"OutputFormat","Matrix");
%save('noisedata200khzfloor',"data")

