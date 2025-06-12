clear; close all;

% ---------------- Geometry & gain & constant definitions -----------------

% Define control constants
Vdc = 10; % DC voltage
Vacx = 300; % AC voltage component in x direction
Vacy = 5; % AC voltage component in y direction
fx = 600;  % frequency in x direction (Hz)
fy = 4;  % frequency in y direction (Hz)
phiy = pi/4; % phase shift in y direction
tEnd = 1.5;  % Final time to model until [s]
t = 0:0.001:tEnd; % time vector from 0 to 1 second with 1 ms interval

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
cx = 2*zeta*sqrt(kx*m);% damping coefficient in x direction
cy = 2*zeta*sqrt(ky*m);% damping coefficient in y direction
gx = 1;                % Drive voltage (input) gain


% ----------------------- Input voltage definition ------------------------

% Drive voltage definition
Vdrive = Vdc + Vacx .* sin(2*pi*fx*t) + Vacy .* sin(2*pi*fy*t + phiy);


% ------------------------ State space definition -------------------------

% let x = [thetax, thetay, thetax', thetay']
A = [0, 0, 1, 0;
     0, 0, 0, 1;
     -kx/Jx, 0, -cx/Jx, 0;
     0, -ky/Jy, 0, -cy/Jy];
B = [0; 0; gx; gx];
C = [1, 0, 0, 0;
     0, 1, 0, 0];
D = 0;

sys = ss(A, B, C, D);


% --------------------------- Simulate system -----------------------------

% Simulate the Vdrive response of system
[yDrive, tDrive] = lsim(sys, Vdrive, t);


% ----------------- Build and display interactive applet ------------------

% Figure initialization
fig1 = uifigure("Name", "MEMS Position Visualizer");
grid1 = uigridlayout(fig1, [1, 2]);
grid1.ColumnWidth = {'1x', '2x'};

% Slider definitions
p = uipanel(grid1, 'Title', 'Input Gain & Frequency');
grid2 = uigridlayout(p, [5 1]);
s_Vdc = uislider(grid2, 'Tag','test');

ax = uiaxes(grid1);
title(ax, 'MEMS Position Data');
xlabel(ax, 'X Position');
ylabel(ax, 'Y Position');

plot(ax, yDrive(:,1), yDrive(:,2));

function updateDrawing(src, event, xr)
    % Update gains from slider values
    % Update the drawing based on the slider value
    Vdc = s_Vdc; % DC voltage
    Vacx = s_Vacx; % AC voltage component in x direction
    Vacy = s_Vacx; % AC voltage component in y direction
    fx = s_fx;  % frequency in x direction (Hz)
    fy = s_fy;  % frequency in y direction (Hz)

    Vdrive = Vdc + gainValue * (Vacx .* sin(2*pi*fx*t) + Vacy .* sin(2*pi*fy*t + phiy));
    [yDrive, tDrive] = lsim(sys, Vdrive, t);
    plot(ax, yDrive(:,1), yDrive(:,2));
end


%% Close all uifigures
all_fig = findall(0, 'type', 'figure');
close(all_fig)