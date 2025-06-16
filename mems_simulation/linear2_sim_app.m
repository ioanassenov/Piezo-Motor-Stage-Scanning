% Title: Interactive MEMS Simulation Applet
% Filename: linear_sim_app.m
% Author: Ioan Assenov
%
% Description: This script is a mini applet which provides an interactive
% linear time invariant model of the MEMS mirror dynamics. It allows the
% user to see how changes in input gains and frequencies approximately
% influence the scanning profile of the MEMS mirror.

clear; close all;

% Define input and system variables as global for interactive changes. This
% is requried for MATLAB to be able to update the simulation plot with
% changes in the slider values.
global s_Vdc s_Vacx s_Vacy s_fx s_fy s_phiy t sys ax;


% ---------------- Geometry & gain & constant definitions -----------------

% Define control constants (these are the initial values)
Vdc = 0;    % DC voltage
Vacx = 1;  % AC voltage component in x direction
Vacy = 1;    % AC voltage component in y direction
fx = 20;    % frequency in x direction (Hz)
fy = 1400;      % frequency in y direction (Hz)
phiy = 0.8; % phase shift in y direction
tEnd = 1;  % Final time to model until [s]
t = 0:0.00001:tEnd; % time vector from 0 to 1 second with 1 ms interval

% Mirror geometry
a = 600e-6/2; % Length of semi-major axis [m]
b = 400e-6/2; % Length of semi-minor axis [m]
h = 20e-6;    % Mirror thickness [m]
V = pi*a*b*h; % Volume of mirror [m^3]

% Define mirror properties
rho = 2300;  % Density of silicon [kg/m^3]
m = rho * V; % Mass [kg];
% Mass moment of inertia about each axis [kg*m^2]
Jx = (1/4) * m * a^2 + (1/12) * m * b^2; % Minor axis
Jy = (1/4) * m * b^2 + (1/12) * m * a^2; % Major axis
% Stiffness and damping properties
zeta = 0.05; % damping ratio estimate
kx = (600*2*pi)^2*Jx;  % spring constant in x direction
ky = (1400*2*pi)^2*Jy; % spring constant in y direction
cx = 2*zeta*sqrt(kx*Jx);% damping coefficient in x direction
cy = 2*zeta*sqrt(ky*Jy);% damping coefficient in y direction
gx = 1;                % Drive voltage (input) gain
gy = gx;


% ----------------------- Input voltage definition ------------------------

% Drive voltage definition
V1 = Vdc + Vacx .* sin(2*pi*fx*t);
V2 = Vacy .* sin(2*pi*fy*t + phiy);
Vdrive = [V1; V2];

% ------------------------ State space definition -------------------------

% let x = [thetax, thetay, thetax', thetay']
A = [0, 0, 1, 0;
     0, 0, 0, 1;
     -kx/Jx, 0, -cx/Jx, 0;
     0, -ky/Jy, 0, -cy/Jy];
B = [0, 0; 0, 0; gx/Jx, gx/Jx; 0, gy/Jy];
C = [1, 0, 0, 0;
     0, 1, 0, 0];
D = 0;

sys = ss(A, B, C, D);


% --------------------------- Simulate system -----------------------------

% Simulate the Vdrive response of system
[yDrive, tDrive] = lsim(sys, Vdrive, t);


% ----------------- Build and display interactive applet ------------------

% Figure initialization
fig1 = uifigure("Name", "MEMS Movement Visualizer");
grid1 = uigridlayout(fig1, [1, 2]);
grid1.ColumnWidth = {'1x', '2x'};

% Slider definitions
p1 = uipanel(grid1, 'Title', 'Input Gain & Frequency');
grid2 = uigridlayout(p1, [5 1]);
s_Vdc  = uieditfield(grid2, 'numeric', 'Value', Vdc, 'ValueDisplayFormat', '%.1f | Vdc', 'ValueChangedFcn', @reSimulate);
s_Vacx = uieditfield(grid2, 'numeric', 'Value', Vacx, 'ValueDisplayFormat', '%.1f | Vacx', 'ValueChangedFcn', @reSimulate);
s_Vacy = uieditfield(grid2, 'numeric', 'Value', Vacy, 'ValueDisplayFormat', '%.1f | Vacy', 'ValueChangedFcn', @reSimulate);
s_fx   = uieditfield(grid2, 'numeric', 'Value', fx, 'ValueDisplayFormat', '%.1f | fx', 'ValueChangedFcn', @reSimulate);
s_fy   = uieditfield(grid2, 'numeric', 'Value', fy, 'ValueDisplayFormat', '%.1f | fy', 'ValueChangedFcn', @reSimulate);
s_phiy = uieditfield(grid2, 'numeric', 'Value', phiy, 'ValueDisplayFormat', '%.1f | phiy', 'ValueChangedFcn', @reSimulate);

ax = uiaxes(grid1);
% xlim(ax, [-20e-7, 20e-7]); ylim(ax, [-20e-7, 20e-7]); 
title(ax, 'MEMS Angular Position');
xlabel(ax, 'X Position [rad]');
ylabel(ax, 'Y Position [rad]');

plot(ax, yDrive(:,1), yDrive(:,2));


% Resimulate function definition: update simulation with new variables
% after entered in the ui edit fields and plot it.
function reSimulate(src, event)
    global s_Vdc s_Vacx s_Vacy s_fx s_fy s_phiy t sys ax;
    
    % Define shorthand local vars for new slider values
    Vdc = s_Vdc.Value;
    Vacx = s_Vacx.Value;
    Vacy = s_Vacy.Value;
    fx = s_fx.Value;
    fy = s_fy.Value;
    phiy = s_phiy.Value;

    % Calculate input function based on new values
    V1 = Vdc + Vacx .* sin(2*pi*fx*t);
    V2 = Vacy .* sin(2*pi*fy*t + phiy);
    Vdrive = [V1; V2];

    % Simulate system and then plot with the new input
    yDrive = lsim(sys, Vdrive, t);
    plot(ax, yDrive(:,1), yDrive(:,2));
end


%% Close all uifigures and clear command window
all_fig = findall(0, 'type', 'figure');
close(all_fig)
clc;