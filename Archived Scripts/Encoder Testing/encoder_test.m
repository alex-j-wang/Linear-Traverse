% -------------------------------------------------------------------------
% Script to run experiments and save dynamic test data
% -------------------------------------------------------------------------

clear; clc; close all hidden;

% Test parameters
% CFS = 54.275; % Crazyflie throttle, %
% SDS = [0.005 0.01 0.02 0.03 0.05 0.07];      % Stopping distance, m
% FS = [0.2 0.5 1 1.5 2];  % Traverse frequency, Hz
% AS = [.025 0.05 0.07];  % Traverse amplitude, m

% DAQ setup
daq_obj = Config.initialize('TargetPosition', 'MeasuredPosition');

% Wait for DAQ setup to stabilize
pause(1);

% Determine position and move near ground plane for calibration
if abs(read(daq_obj).TargetPosition) > 2 || input('Is traverse at home position [y/n]? ', 's') ~= 'y'
    disp('Identifying position.')
    position = Process.get_position(daq_obj);
    fprintf('Position identified as %.1f cm.\n', position * 100);
    position = Process.gradual_move(daq_obj, position, 0);
else
    position = 0;
end
position = Process.gradual_move(daq_obj, position, -0.125);

% Encoder calibration
disp('Calibrating encoder.');
[position, encoder] = Process.gradual_move(daq_obj, position, 0.125);
lpi = double(encoder(1) - encoder(end)) / (0.25 * 100 / 2.54);
fprintf('Encoder calibration: %.1f lines per inch.\n', lpi);

% Move to starting position
shift = 0;
position = Process.gradual_move(daq_obj, position, shift);
pause(1);

CF = 0;
F = 1;
A = 0.05;

% Gather data
[time, voltages, tare_voltages, target, measured, pos_encoder] = ...
    dynamic_operation(CF, shift, F, A, daq_obj, lpi, Config.Position);