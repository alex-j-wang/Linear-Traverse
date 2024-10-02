clear; clc; close all hidden;

% Load the calibration matrix for the force transducer
load(['cal_' Config.SENSOR '.mat']);

% DAQ setup
daq_obj = Config.initialize('TargetPosition', 'MeasuredPosition');

tare_output = zeros(Config.OFFSET_DURATION * Config.SRATE, 1);
disp('Taring output.');
tare_start = mean(readwrite(daq_obj, tare_output, 'OutputFormat', 'Matrix'));
tare_start = tare_start(1:6);

% Static 30 seconds
profile = zeros(30 * Config.SRATE, 1);

disp('Collecting data.');
data = readwrite(daq_obj, profile, 'OutputFormat', 'Matrix');
disp('Data collected.');

disp('Taring output.');
tare_end = mean(readwrite(daq_obj, tare_output, 'OutputFormat', 'Matrix'));
tare_end = tare_end(1:6);

tare_voltages = (tare_start + tare_end) / 2;
voltages = data(:, 1:6) - tare_voltages;
forces = (cal_mat * voltages')'; % Conversion to forces and moments

Process.format_plot('Normalized Force & Torque vs. Time', 'Time (s)', 'Normalized Force & Torque');
plot(0:1/Config.SRATE:(30 - 1/Config.SRATE), forces(:, 1:3) / Config.W);
plot(0:1/Config.SRATE:(30 - 1/Config.SRATE), forces(:, 4:6) / Config.W / Config.L);
legend(Config.NAMES);
save('enabled_new', 'forces', 'tare_start', 'tare_end', 'tare_voltages');
disp(tare_start);
disp(tare_end);