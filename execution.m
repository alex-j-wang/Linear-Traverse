% -------------------------------------------------------------------------
% Script to run experiments and save dynamic test data
% -------------------------------------------------------------------------

clear; clc; close all hidden;

% Test parameters
CFS = [0 25 50];         % Crazyflie throttle, %
SDS = [0.005 0.01 0.02]; % Stopping distance, m
FS = [0.2 0.5 1 1.5];    % Traverse frequency, Hz
AS = [0.05 0.08];        % Traverse amplitude, m

% DAQ setup
daq_obj = Config.initialize("TargetPosition", "MeasuredPosition");

% Load the calibration matrix for the force transducer
load("cal_FT21128.mat");

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
disp("Identifying position.")
position = Process.get_position(daq_obj);
disp("Position identified as " + position * 100 + " cm.");
Process.gradual_move(daq_obj, position, 0);
ground = -input("Enter distance from ground plane (cm): ") / 100;

est_time = seconds(length(CFS) * length(SDS) * length(AS) * ...
    (Config.TOTAL_CYCLES * sum(1 ./ FS) + Config.OFFSET_DURATION * length(FS)));
est_time.Format = 'hh:mm:ss';
est_elapsed = seconds(0);
est_elapsed.Format = 'hh:mm:ss';

% Create waitbar
h = uifigure('Name', 'Dynamic Testing');
d = uiprogressdlg(h, 'Title', 'Dynamic Testing');

position = 0;
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
                message = sprintf("Estimated execution time: %s\nElapsed time: %s\nCase: %s", ...
                    est_time, actual_elapsed, strrep(case_name, '_', ' '));
                d.Value = est_elapsed / est_time;
                d.Message = message;

                % Move to starting position
                shift = ground + A + SD;
                position = Process.gradual_move(daq_obj, position, shift);
                pause(1);

                % Gather data
                [time, forces, ~, ~, pos_encoder] = ...
                    dynamic_operation(CF, shift, F, A, daq_obj, cal_mat, Config.Position);

                % Save data
                filename = fullfile(date_string, case_name + '.mat');
                save(filename, "time", "forces", "pos_encoder");
                disp("Data saved to " + filename + ".");

                % Preliminary analysis
                mean_forces = mean(forces);
                std_forces = std(forces);

                disp("Measurements: mean (stdev)");
                for i = 1:6
                    fprintf("%s: %.3g (%.3g)\n", Config.NAMES(i), mean_forces(i), std_forces(i));
                end

                est_elapsed = est_elapsed + seconds(Config.TOTAL_CYCLES * (1 / F) + Config.OFFSET_DURATION);
            end
        end
    end
end

actual_elapsed = seconds(toc);
actual_elapsed.Format = 'hh:mm:ss';
message = sprintf("Estimated execution time: %s\nElapsed time: %s", est_time, actual_elapsed);
d.Value = 1;
d.Message = message;
pause(3);
close(h);