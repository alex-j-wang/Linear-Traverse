clear; clc; close all hidden;

% Constant parameters
DATA_CYCLES = 20; % Cycles of data for phase averaging
RAMP_CYCLES = 4; % Cycles for ramping up and down

% Test parameters
AS = 0.025:0.025:0.1; % Traverse amplitude, m
FS = 0.5:0.1:4; % Traverse frequency, Hz

% DAQ setup
SRATE = 20000; % Data sampling rate, Hz
DTOV = 1 / .02; % Conversion factor from distance to voltage, V/m

disp("Setting up DAQ.");
daq_obj = daq("ni");
daq_obj.Rate = SRATE;

% Output channel (motor voltage)
output = addoutput(daq_obj, "Dev2", "ao0", "Voltage");
output.Name = "voutput";

% Input channels (force sensor and motor position)
input_channels = addinput(daq_obj, "Dev2", 0:6, "Voltage");
input_channels(7).Name = "MotorPosition";

% Load the calibration matrix for the force transducer
load("cal_FT21128.mat");

% Column names
names = ["F_x" "F_y" "F_z" "M_x" "M_y" "M_z"];

% Wait for DAQ setup to stabilize
pause(1);

est_time = seconds(length(AS) * ((DATA_CYCLES + 2 * RAMP_CYCLES) * sum(1 ./ FS)));
est_time.Format = 'hh:mm:ss';
est_elapsed = seconds(0);
est_elapsed.Format = 'hh:mm:ss';

% Create waitbar
h = uifigure('Name', 'Limit Testing');
d = uiprogressdlg(h, 'Title', 'Limit Testing');

position = 0;
tic

% ACQUIRE DATA
for A = AS        
    for F = FS
        case_name = sprintf("F%g_A%g", F, A * 100);
        disp("Running <strong>" + strrep(case_name, '_', ' ') + "</strong>.");

        actual_elapsed = seconds(toc);
        actual_elapsed.Format = 'hh:mm:ss';
        message = sprintf("Estimated execution time: %s\nElapsed time: %s\nCase: %s", ...
            est_time, actual_elapsed, strrep(case_name, '_', ' '));
        d.Value = est_elapsed / est_time;
        d.Message = message;

        % Gather data
        [time, ~, motor_position, position] = ...
            dynamic_operation(0, 0, F, A, DATA_CYCLES, RAMP_CYCLES, 0.5, DTOV, daq_obj, cal_mat);
        position = position';

        % Save data
        filename = fullfile("Limit Analysis", case_name + '.mat');
        save(filename, "time", "position", "motor_position");
        disp("Data saved to " + filename + ".");

        est_elapsed = est_elapsed + seconds((DATA_CYCLES + 2 * RAMP_CYCLES) * (1 / F) + OFFSET_DURATION);
    end
end

actual_elapsed = seconds(toc);
actual_elapsed.Format = 'hh:mm:ss';
message = sprintf("Estimated execution time: %s\nElapsed time: %s", est_time, actual_elapsed);
d.Value = 1;
d.Message = message;
pause(3);
close(h);