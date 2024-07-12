% --------------------------------------------------------------------
% Script to obtain target and measured position data for comparison
% --------------------------------------------------------------------

clear; clc; close all hidden;

% Test parameters
AS = 0.025:0.025:0.075; % Traverse amplitude, m
FS = 0.1:0.3:3; % Traverse frequency, Hz

% DAQ setup
daq_obj = Config.initialize("TargetPosition", "MeasuredPosition");

% Load the calibration matrix for the force transducer
load("cal_FT21128.mat");

% Wait for DAQ setup to stabilize
pause(1);

est_time = seconds(length(AS) * Config.TOTAL_CYCLES * sum(1 ./ FS));
est_time.Format = 'hh:mm:ss';
est_elapsed = seconds(0);
est_elapsed.Format = 'hh:mm:ss';

% Create waitbar
h = uifigure('Name', 'Position Testing');
d = uiprogressdlg(h, 'Title', 'Position Testing', 'Indeterminate', 'on');
input("Ensure Driveware inputs are configured for position. Press Enter to continue.")
d.Indeterminate = 'off';
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
        [time, ~, pos_target, pos_measured, pos_encoder] = ...
            dynamic_operation(0, 0, F, A, daq_obj, cal_mat, Config.Position);

        % Save data
        filename = fullfile("Position Data", case_name + '.mat');
        save(filename, "time", "pos_target", "pos_measured", "pos_encoder");
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