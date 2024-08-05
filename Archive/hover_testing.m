% -------------------------------------------------------------------------
% Script to determine static hover throttle using force data
% -------------------------------------------------------------------------

clear; clc; close all hidden;

% Load the calibration matrix for the force transducer
load(['cal_' Config.SENSOR '.mat']);

disp('Ensure traverse is disabled. Press ENTER to continue...');
pause;

% DAQ setup
daq_obj = Config.initialize('TargetPosition', 'MeasuredPosition');

tare_output = zeros(Config.OFFSET_DURATION * Config.SRATE, 1);
disp('Taring output.');
tare_voltages = mean(readwrite(daq_obj, tare_output, 'OutputFormat', 'Matrix'));
tare_voltages = tare_voltages(1:6);

throttles = 0:5:100;
all_forces = zeros(length(throttles), 6);

for idx = 1 : length(throttles)
    CF = throttles(idx);
    if CF ~= 0
        fprintf('Starting Crazyflie at %d throttle.\n', CF);
        Process.run_drone(CF);
        pause(1);
    end

    % Static 30 seconds
    profile = zeros(30 * Config.SRATE, 1);
    
    disp('Collecting data.');
    data = readwrite(daq_obj, profile, 'OutputFormat', 'Matrix');
    disp('Data collected.');

    voltages = data(:, 1:6) - tare_voltages;
    forces = (cal_mat * voltages')'; % Conversion to forces and moments
    all_forces(idx, :) = mean(forces); % Save averages to matrix
end

disp('Stopping Crazyflie.');
Process.run_drone(0);

Process.format_plot('Normalized Force & Torque vs. Throttle', 'Throttle (%)', 'Normalized Force & Torque');
plot(throttles, all_forces(:, 1:3) / Config.W);
plot(throttles, all_forces(:, 4:6) / Config.W / Config.L);
legend(Config.NAMES);