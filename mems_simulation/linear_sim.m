% Title: Static MEMS Simulation Using State Space
% Filename: linear_sim.m
% Author: Ioan Assenov
%
% Description: This script is the precursor to linear_sim_app.m. It was
% used to establish a quick and accurate solution to the linear model of
% the MEMS mirror before being turned into an interactive app.

clear; close all;

% ---------------- Geometry & gain & constant definitions -----------------

% Define control constants
Vdc = 10; % DC voltage
Vacx = 300; % AC voltage component in x direction
Vacy = 5; % AC voltage component in y direction
fx = 1;  % frequency in x direction (Hz)
fy = 300;  % frequency in y direction (Hz)
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
kx = (600*2*pi)^2*Jx;   % spring constant in x direction
ky = (1400*2*pi)^2*Jy;  % spring constant in y direction
cx = 2*zeta*sqrt(kx*Jx);% damping coefficient in x direction
cy = 2*zeta*sqrt(ky*Jy);% damping coefficient in y direction
% Drive voltage (input) gains
gx = 1;
gy = gx;

% ----------------------- Input voltage definition ------------------------

% Drive voltage definition
Vdrive = Vdc + Vacx .* sin(2*pi*fx*t) + Vacy .* sin(2*pi*fy*t + phiy);


% ------------------------ State space definition -------------------------

% let x = [thetax, thetay, thetax', thetay']
A = [0, 0, 1, 0;
     0, 0, 0, 1;
     -kx/Jx, 0, -cx/Jx, 0;
     0, -ky/Jy, 0, -cy/Jy];
B = [0; 0; gx/Jx; gy/Jy];
C = [1, 0, 0, 0;
     0, 1, 0, 0];
D = 0;

sys = ss(A, B, C, D);


% ---------------------- Model for different inputs -----------------------

% Simulate the step response of the system
[yOut, tOut] = step(sys, t);

% Simulate the Vdrive response of system
[yDrive, tDrive] = lsim(sys, Vdrive, t);


% ----------------------- Plot for different inputs -----------------------

% Plot step response
% figure;
% subplot(2, 1, 1);
% plot(tOut, yOut);
% title('Step Response');
% xlabel('Time [s]'); ylabel('Output Response [rad]');
% subplot(2, 1, 2);
% plot([0, t(end)], [1, 1]);
% title('Input voltage');
% xlabel('Time [s]'); ylabel('Driving Voltage [V]');

% Plot driving voltage response
figure;
subplot(2, 1, 1);
plot(tDrive, yDrive);
title('Drive Voltage');
xlabel('Time [s]'); ylabel('Output Response [rad]');
legend('\theta_x', '\theta_y');
subplot(2, 1, 2);
plot(t, Vdrive);
title('Input voltage');
xlabel('Time [s]'); ylabel('Driving Voltage [V]');

% Plot mems mirror movement in 2D
figure;
xlabel('\theta_x'); ylabel('\theta_y');
comet(yDrive(:, 1), yDrive(:, 2));
