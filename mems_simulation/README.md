# Linear MEMS Simulation
This is a linear time-invariant simulation of the mems mirror's scanning
pattern. It solves the following equations of motion:

$J_x \ddot\theta_x + c_x \dot\theta_x + k_x \theta_x = g_x V_{drive}$

$J_y \ddot\theta_y + c_y \dot\theta_y+ k_y \theta_y = g_y V_{drive}$

where the drive voltage input is defined by

$V_{drive} = V_{DC} + V_{AC, x}\sin(2 \pi f_xt) + V_{AC,y}\sin(2 \pi f_y t + \phi_y)$

With $V_{DC}$, $V_{AC,q}$, $f_q$, and $\phi_y$ being
arbitrary constants. $\theta_x(t)$ and $\theta_y(t)$ represent the angular
position of the mirror over time.

## MEMS Mirror
The mirror is an ellipse with a major axis of 600 micrometers and a minor
axis of 400 micrometers. The stiffnesses and damping coefficients are
defined based on the natural frequencies:

$\frac{1}{2\pi} \sqrt{\frac{k_x}{J_x}} = 600 \text{Hz}$ and
$\frac{1}{2\pi} \sqrt{\frac{k_y}{J_y}} = 1400 \text{Hz}$

$\frac{c_q}{J_q} = 2\zeta\omega_{n,q}$ where $q$ is the coordinate $x$ or $y$.

These values for the natural frequencies are based on experimental data.