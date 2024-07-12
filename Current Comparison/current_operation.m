% --------------------------------------------------------------------
% Script to obtain demanded and measured current data for comparison
% --------------------------------------------------------------------

clear; clc; close all hidden;

% Test parameters
AS = 0.025:0.025:0.075; % Traverse amplitude, m
FS = 0.1:0.3:3; % Traverse frequency, Hz

% DAQ setup
daq_obj = Config.initialize("CurrentDemand", "CurrentMeasured");

% Load the calibration matrix for the force transducer
load("cal_FT21128.mat");

% Wait for DAQ setup to stabilize
pause(1);

est_time = seconds(length(AS) * Config.TOTAL_CYCLES * sum(1 ./ FS));
est_time.Format = 'hh:mm:ss';
est_elapsed = seconds(0);
est_elapsed.Format = 'hh:mm:ss';

% Create waitbar
h = uifigure('Name', 'Current Testing');
d = uiprogressdlg(h, 'Title', 'Current Testing', 'Indeterminate', 'on');
input("Ensure Driveware inputs are configured for current. Press Enter to continue.")
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
        [time, ~, curr_target, curr_measured] = ...
            dynamic_operation(0, 0, F, A, daq_obj, cal_mat, Config.Current);

        % Save data
        filename = fullfile("Current Data", case_name + '.mat');
        save(filename, "time", "curr_target", "curr_measured");
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