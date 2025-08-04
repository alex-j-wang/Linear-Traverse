clear; clc; close all hidden;

% Load the calibration matrix for the force transducer
load(['cal_' Config.SENSOR '.mat']);

folder = "C:\Users\awang127\Documents\MATLAB\Linear-Traverse\Data\2024_12_06_DYN";
filename = "CF54.275_SD2_F1_A9.mat";
MAX = 0.625;

load(fullfile(folder, filename));

forces = (cal_mat * voltages')'; % Conversion to forces and moments

% Extract and convert parameters
parameters = num2cell(sscanf(filename, 'CF%f_SD%f_F%f_A%f.mat'));
[CF, SD, F, A] = deal(parameters{:});
SD = SD / 100;
A = A / 100;
T = 1 / F;
FC = 20;

% figure('Position', [476 360 560 120]);
% Process.format_plot("Raw Thrust", "Time (s)", "Thrust (N)");
% plot(time, forces(:, 3));

pad_length = 50;
padded = vertcat(repmat(mean(forces(1:200, :)), pad_length, 1), forces);

% Apply Butterworth filter
[b, a] = butter(6, FC / (Config.SRATE / 2));
filtered = zeros(size(forces));
for col = 1:6
    filt = filtfilt(b, a, padded(:, col));
    filtered(:, col) = filt(pad_length + 1:end);
end

% figure('Position', [476 360 560 120]);
% Process.format_plot("Filtered Thrust (FC = 20)", "Time (s)", "Thrust (N)");
% plot(time, filtered(:, 3));

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

% total_force(:, 3) = smooth(total_force(:, 3), length(total_force(:, 3)) / 10);

figure('Position', [680 458 560*1.35 420*1.35])
Process.format_plot('', 'Time (t/T)', 'Thrust (AU)');
plot(time(1 : phase_width), squeeze(stacked(:, 3, :)) / Config.W / MAX, 'Color', [161, 201, 227] / 255)
plot(time(1 : phase_width), total_force(:, 3) / Config.W / MAX, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5);

% % Phase average position
% stacked = reshape(pos_encoder, phase_width, []);
% pos_encoder = mean(stacked, 2);
% plot(time(1 : phase_width), pos_encoder * 10, 'Color', '#EDB120', 'LineWidth', 1.5);

set(gcf, 'Renderer', 'painters');

disp(total_force(1, 3) / Config.W / MAX - total_force(end, 3) / Config.W / MAX)