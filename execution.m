clear; clc; close all hidden;

% Constant parameters
DATA_CYCLES = 40; % Cycles of data for phase averaging
RAMP_CYCLES = 4; % Cycles for ramping up and down
OFFSET_DURATION = 10; % Duration for zeroing force transducer, s

% Test parameters
CFS = [0 25]; % Crazyflie throttle, %
SDS = 0.05; % Stopping distance, m
FS = 0.5:0.1:0.9; % Traverse frequency, Hz
AS = 0.05; % Traverse amplitude, m

% DAQ setup
SRATE = 20000; % Data sampling rate, Hz
DTOV = 1 / .02; % Conversion factor from distance to voltage, V/m
SHIFT_SPEED = 0.05; % m/s
CAL_SAMPLES = 3000; % Samples for position calibration

disp("Setting up DAQ.");
daq_obj = daq("ni");
daq_obj.Rate = SRATE;

% Output channel (motor voltage)
output = addoutput(daq_obj, "Dev2", "ao0", "Voltage");
output.Name = "voutput";

% Input channels (force sensor and motor position)
input_channels = addinput(daq_obj, "Dev2", 0:6, "Voltage");
for i = 1:6
    input_channels(i).Name = "ForceSensor" + i;
end
input_channels(7).Name = "MotorPosition";

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
position = get_position(daq_obj, DTOV, CAL_SAMPLES);
disp("Position identified as " + position * 100 + " cm.");
disp("Moving to home.");
if position > 0
    gradual_shift = position * DTOV : -SHIFT_SPEED * DTOV / SRATE : 0;
else
    gradual_shift = position * DTOV : +SHIFT_SPEED * DTOV / SRATE : 0;
end
readwrite(daq_obj, gradual_shift');
ground = -input("Enter distance from ground plane (cm): ") / 100;

est_time = seconds(length(CFS) * length(SDS) * length(AS) * ...
    ((DATA_CYCLES + 2 * RAMP_CYCLES) * sum(1 ./ FS) + OFFSET_DURATION * length(FS)));
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
                if position > shift
                    gradual_shift = position * DTOV : -SHIFT_SPEED * DTOV / SRATE : shift * DTOV;
                    disp("Moving to " + shift * 100 + " cm.");
                    readwrite(daq_obj, gradual_shift');
                elseif position < shift
                    gradual_shift = position * DTOV : +SHIFT_SPEED * DTOV / SRATE : shift * DTOV;                
                    disp("Moving to " + shift * 100 + " cm.");
                    readwrite(daq_obj, gradual_shift');
                end
                position = shift;
                pause(1);

                % Gather data
                [time, forces, motor_position] = ...
                    dynamic_operation(CF, shift, F, A, DATA_CYCLES, RAMP_CYCLES, OFFSET_DURATION, DTOV, daq_obj, cal_mat);

                % Save data
                filename = fullfile(date_string, case_name + '.mat');
                save(filename, "time", "forces", "motor_position");
                disp("Data saved to " + filename + ".");

                % Preliminary analysis
                mean_forces = mean(forces);
                std_forces = std(forces);

                disp("Measurements: mean (stdev)");
                for i = 1:6
                    fprintf("%s: %.3g (%.3g)\n", names(i), mean_forces(i), std_forces(i));
                end

                est_elapsed = est_elapsed + seconds((DATA_CYCLES + 2 * RAMP_CYCLES) * (1 / F) + OFFSET_DURATION);
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

function position = get_position(daq_obj, DTOV, CAL_SAMPLES)
    position = zeros(CAL_SAMPLES, 1);
    for i = 1 : CAL_SAMPLES
        position(i) = read(daq_obj).MotorPosition / DTOV;
    end
    position = mean(position);
end