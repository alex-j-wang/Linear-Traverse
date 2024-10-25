% -------------------------------------------------------------------------
% Plots all force cycles, phase averaged forces, and encoder
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
FC = 20;

[time, voltages, tare_voltages, ~, ~, pos_encoder] = ...
    dynamic_operation(CF, 0, F, A, daq_obj, Config.LPI, Config.Position);
forces = (cal_mat * voltages')'; % Conversion to forces and moments

% Apply Butterworth filter
[b, a] = butter(6, FC / (Config.SRATE / 2));
filtered = zeros(size(forces));
for col = 1:6
    filtered(:, col) = filtfilt(b, a, forces(:, col));
end

figure
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

figure
Process.format_plot('Windowed F_z Versus Time', 'Time (s)', 'Normalized F_z');
plot(time(1 : phase_width), squeeze(stacked(:, 3, :)) / Config.W, 'Color', [0 0.4470 0.7410 0.2])
plot(time(1 : phase_width), total_force(:, 3 ) / Config.W, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5);

% Phase average position
stacked = reshape(pos_encoder, phase_width, []);
pos_encoder = mean(stacked, 2);
plot(time(1 : phase_width), pos_encoder * 10, 'Color', '#EDB120', 'LineWidth', 1.5);