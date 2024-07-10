clear; clc; close all hidden;

% Test parameters
CFS = [0 50]; % Crazyflie throttle, %
SDS = [.005 .01]; % Stopping distance, m
FS = [0.5 1]; % Traverse frequency, Hz
AS = [0.025 0.05 0.1]; % Traverse amplitude, m

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

% Column names
names = ["F_x" "F_y" "F_z" "M_x" "M_y" "M_z"];

% Wait for DAQ setup to stabilize
pause(1);

% Temporary solution until possible to read multiple scans without writing
disp("Identifying position.")
position = get_position(daq_obj);
disp("Position identified as " + position * 100 + " cm.");
disp("Moving to home.");
if position > 0
    gradual_shift = Config.DTOV * (position : -Config.TICKSHIFT : 0);
else
    gradual_shift = Config.DTOV * (position : +Config.TICKSHIFT : 0);
end
readwrite(daq_obj, gradual_shift');
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
                if position > shift + Config.TICKSHIFT
                    gradual_shift = Config.DTOV * (position : -Config.TICKSHIFT : shift);
                    disp("Moving to " + shift * 100 + " cm.");
                    readwrite(daq_obj, gradual_shift');
                elseif position < shift - Config.TICKSHIFT
                    gradual_shift = Config.DTOV * (position : +Config.TICKSHIFT : shift);
                    disp("Moving to " + shift * 100 + " cm.");
                    readwrite(daq_obj, gradual_shift');
                end
                position = shift;
                pause(1);

                % Gather data
                [time, forces, ~, pos_measured] = ...
                    dynamic_operation(CF, shift, F, A, daq_obj, cal_mat, Config.Position);

                % Save data
                filename = fullfile(date_string, case_name + '.mat');
                save(filename, "time", "forces", "pos_measured");
                disp("Data saved to " + filename + ".");

                % Preliminary analysis
                mean_forces = mean(forces);
                std_forces = std(forces);

                disp("Measurements: mean (stdev)");
                for i = 1:6
                    fprintf("%s: %.3g (%.3g)\n", names(i), mean_forces(i), std_forces(i));
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

function position = get_position(daq_obj)
    position = zeros(Config.CAL_SAMPLES, 1);
    for i = 1 : Config.CAL_SAMPLES
        position(i) = read(daq_obj).MotorPosition * Config.VTOD;
    end
    position = mean(position);
end