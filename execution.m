% -------------------------------------------------------------------------
% Script to run experiments and save dynamic test data
% -------------------------------------------------------------------------

clear; clc; close all hidden;

% Test parameters
CFS = 0;                                 % Crazyflie throttle, %
SDS = [0.005 0.01 0.02 0.025 0.03 0.05]; % Stopping distance, m
FS = [0.2 0.5 1 1.5 2];                  % Traverse frequency, Hz
AS = [0.025 0.05 0.08];                  % Traverse amplitude, m
% CFS = [0 75]; % Crazyflie throttle, %
% SDS = 0.01; % Stopping distance, m
% FS = 1; % Traverse frequency, Hz
% AS = 0.05; % Traverse amplitude, m

% DAQ setup
daq_obj = Config.initialize("TargetPosition", "MeasuredPosition");

% Create folder for record-keeping
date_string = string(datetime("now", "Format", "yyyy_MM_dd"));
if exist(date_string, "dir")
    disp("Experiment may overwrite data. Press ENTER to continue...");
    pause;
else
    mkdir(date_string);
end

% Wait for DAQ setup to stabilize
pause(1);

% Temporary solution until possible to read multiple scans without writing
if input("Is traverse at home position [y/n]? ", "s") ~= "y"
    disp("Identifying position.")
    position = Process.get_position(daq_obj);
    disp("Position identified as " + position * 100 + " cm.");
    position = Process.gradual_move(daq_obj, position, 0);
end
position = Process.gradual_move(daq_obj, position, -0.1);
ground = position - input("Enter distance from ground plane (cm): ") / 100;

% Encoder calibration
disp("Calibrating encoder.");
[position, encoder] = Process.gradual_move(daq_obj, position, 0.1);
lpi = abs(range(encoder)) / (0.2 * 100 / 2.54);
disp("Encoder calibrated at " + round(lpi) + " lines per inch.");

est_time = seconds(length(CFS) * length(SDS) * length(AS) * ...
    (Config.TOTAL_CYCLES * sum(1 ./ FS) + 2 * Config.OFFSET_DURATION * length(FS)));
est_time.Format = 'hh:mm:ss';
est_elapsed = seconds(0);
est_elapsed.Format = 'hh:mm:ss';

% Create waitbar
h = uifigure('Name', 'Dynamic Testing');
d = uiprogressdlg(h, 'Title', 'Dynamic Testing');

tic

% ACQUIRE DATA
for CF = CFS
    for SD = SDS
        for F = FS
            for A = AS
                case_name = sprintf("CF%g_SD%g_F%g_A%g", CF, SD * 100, F, A * 100);
                disp("Running <strong>" + strrep(case_name, '_', ' ') + "</strong>.");

                actual_elapsed = seconds(toc);
                actual_elapsed.Format = 'hh:mm:ss';
                est_remaining = est_time - est_elapsed;
                est_remaining.Format = 'hh:mm:ss';
                message = sprintf("Estimated time: %s / %s (%s left)\nElapsed time: %s\nCase: %s", ...
                    est_elapsed, est_time, est_remaining, actual_elapsed, strrep(case_name, '_', ' '));
                d.Value = est_elapsed / est_time;
                d.Message = message;

                % Move to starting position
                shift = ground + A + SD;
                position = Process.gradual_move(daq_obj, position, shift);
                pause(1);

                % Gather data
                [time, voltages, tare_voltages, ~, ~, pos_encoder] = ...
                    dynamic_operation(CF, shift, F, A, daq_obj, lpi, Config.Position);

                % Save data
                filename = fullfile(date_string, case_name + '.mat');
                save(filename, "time", "voltages", "tare_voltages", "pos_encoder");
                disp("Data saved to " + filename + ".");

                est_elapsed = est_elapsed + seconds(Config.TOTAL_CYCLES * (1 / F) + 2 * Config.OFFSET_DURATION);
            end
        end
    end
end

actual_elapsed = seconds(toc);
actual_elapsed.Format = 'hh:mm:ss';
message = sprintf("Estimated time: %s / %s\nElapsed time: %s", est_elapsed, est_time, actual_elapsed);
d.Value = 1;
d.Message = message;

pause(3);
close(h);