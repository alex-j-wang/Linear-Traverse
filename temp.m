clear; clc; close all hidden;

% Constant parameters
DATA_CYCLES = 20; % Cycles of data for phase averaging
RAMP_CYCLES = 4; % Cycles for ramping up and down

% Test parameters
AS = 0.025:0.025:0.075; % Traverse amplitude, m
FS = 0.1:0.3:3; % Traverse frequency, Hzn

% DAQ setup
SRATE = 20000; % Data sampling rate, Hz
DTOV = 1 / .02; % Conversion factor from distance to voltage, V/m
ITOV = 10 / 1; % Conversion factor from current to voltage, V/A

disp("Setting up DAQ.");
daq_obj = daq("ni");
daq_obj.Rate = SRATE;

% Output channel (motor voltage)
output = addoutput(daq_obj, "Dev2", "ao0", "Voltage");
output.Name = "voutput";

% Input channels (force sensor and motor position)
input_channels = addinput(daq_obj, "Dev2", 0:7, "Voltage");
for i = 1:6
    input_channels(i).Name = "ForceSensor" + i;
end
input_channels(7).Name = "CurrentDemand";
input_channels(8).Name = "CurrentMeasured";

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
h = uifigure('Name', 'Current Comparison');
d = uiprogressdlg(h, 'Title', 'Current Comparison');

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
        [time, ~, measured, demand] = ...
            dynamic_operation(0, 0, F, A, DATA_CYCLES, RAMP_CYCLES, 0.5, DTOV, daq_obj, cal_mat);

        % Save data
        filename = fullfile("Current Comparison", case_name + '.mat');
        save(filename, "time", "demand", "measured");
        disp("Data saved to " + filename + ".");

        est_elapsed = est_elapsed + seconds((DATA_CYCLES + 2 * RAMP_CYCLES) * (1 / F));
    end
end

actual_elapsed = seconds(toc);
actual_elapsed.Format = 'hh:mm:ss';
message = sprintf("Estimated execution time: %s\nElapsed time: %s", est_time, actual_elapsed);
d.Value = 1;
d.Message = message;
pause(3);
close(h);

doesn't work yet!!! need to transfer both conversion factors