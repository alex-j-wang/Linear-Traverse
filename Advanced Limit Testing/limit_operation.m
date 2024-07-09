clear; clc; close all hidden;

% Test parameters
AS = 0.025:0.025:0.075; % Traverse amplitude, m
FS = 0.1:0.3:3; % Traverse frequency, Hz

% DAQ setup
disp("Setting up DAQ.");
daq_obj = daq("ni");
daq_obj.Rate = Config.SRATE;

% Output channel (motor voltage)
output = addoutput(daq_obj, "Dev2", "ao0", "Voltage");
output.Name = "voutput";

% Input channels (force sensor and motor position)
input_channels = addinput(daq_obj, "Dev2", 0:7, "Voltage");
for i = 1:6
    input_channels(i).Name = "ForceSensor" + i;
end
input_channels(7).Name = "TargetPosition";
input_channels(8).Name = "MeasuredPosition";

% Load the calibration matrix for the force transducer
load("cal_FT21128.mat");

% Wait for DAQ setup to stabilize
pause(1);

est_time = seconds(length(AS) * Config.TOTAL_CYCLES * sum(1 ./ FS));
est_time.Format = 'hh:mm:ss';
est_elapsed = seconds(0);
est_elapsed.Format = 'hh:mm:ss';

% Create waitbar
h = uifigure('Name', 'Limit Testing');
d = uiprogressdlg(h, 'Title', 'Limit Testing');

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
        [time, ~, pos_target, pos_measured] = ...
            dynamic_operation(0, 0, F, A, daq_obj, cal_mat, Config.Position);

        % Save data
        filename = fullfile("Limit Analysis", case_name + '.mat');
        save(filename, "time", "position", "motor_position");
        disp("Data saved to " + filename + ".");

        est_elapsed = est_elapsed + seconds(Config.TOTAL_CYCLES * (1 / F));
    end
end

actual_elapsed = seconds(toc);
actual_elapsed.Format = 'hh:mm:ss';
message = sprintf("Estimated execution time: %s\nElapsed time: %s", est_time, actual_elapsed);
d.Value = 1;
d.Message = message;
pause(3);
close(h);