% -------------------------------------------------------------------------
% Script to determine static hover throttle using force data
% -------------------------------------------------------------------------

clear; clc; close all hidden;

% Load the calibration matrix for the force transducer
load(['cal_' Config.SENSOR '.mat']);

disp('Ensure traverse is home. Press ENTER to continue...');
pause;

% DAQ setup
daq_obj = Config.initialize('TargetPosition', 'MeasuredPosition');

CF = 0;
SD = 0.005;
F = 1;
A = 0;
T = 1 / F;
FC = Config.FCM * F;

[time, voltages, tare_voltages, ~, ~, pos_encoder] = ...
    dynamic_operation(CF, shift, F, A, daq_obj, lpi, Config.Position);
forces = (cal_mat * voltages')'; % Conversion to forces and moments

% Apply Butterworth filter
[b, a] = butter(6, FC / (Config.SRATE / 2));
filtered = zeros(size(forces));
for col = 1:6
    filtered(:, col) = -filtfilt(b, a, forces(:, col));
end

Process.format_plot('Normalized F_z Versus Time', 'Time (s)', 'Normalized F_z');
plot(time, filtered(:, 3) / Config.W, 'LineWidth', 1.5);

% Phase average forces
phase_width = T * Config.SRATE;
frac = mod(phase_width, 1);

% Check for fractional phase width, eliminate entries to support integral phase width
if frac ~= 0
    range = phase_width : phase_width : length(filtered) + 1;
    select = mod(frac * (1 : length(range)), 1) < frac;
    range = floor(range);
    keep = true(1, length(filtered));
    keep(range(select)) = false;
    filtered = filtered(keep, :);
    pos_encoder = pos_encoder(keep);
    phase_width = floor(phase_width);
end

stacked = pagetranspose(reshape(filtered', 6, phase_width, []));
total_force = mean(stacked, 3);

Process.format_plot('Windowed F_z Versus Time', 'Time (s)', 'Normalized F_z');
ll = patch([time(1 : phase_width); nan], [squeeze(stacked(3, :, :)) / Config.W; nan], 'r');
set(ll, 'EdgeColor', 'r', 'EdgeAlpha', 0.05);
plot(time, total_force(3, :) / Config.W, 'LineWidth', 1.5);

% % Phase average position
% stacked = reshape(pos_encoder, phase_width, []);
% pos_encoder = mean(stacked, 2);