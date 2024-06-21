clear; clc; close all;

% Constant parameters
DATA_CYCLES = 40; % Cycles of data for phase averaging
RAMP_CYCLES = 4; % Cycles for ramping up and down
OFFSET_DURATION = 10; % Duration for zeroing force transducer, s

% Test parameters
CFS = 75; % Crazyflie throttle, %
SDS = 0.5 / 100; % Stopping distance, m
FS = 0.3:0.3:1; % Traverse frequency, Hz
AS = 0.025:0.025:0.1; % Traverse amplitude, m

% DAQ setup
SRATE = 20000; % Data sampling rate, Hz
DTOV = 1 / .02; % Conversion factor from distance to voltage, V/m

disp("Setting up DAQ");
daq_obj = daq("ni");
daq_obj.Rate = SRATE;

% Output channel (motor voltage)
output = addoutput(daq_obj, "Dev2", "ao0", "Voltage");
output.Name = "voutput";

% Input channels (force sensor and motor position)
input = addinput(daq_obj, "Dev2", 0:6, "Voltage");
for i = 1:6
    input(i).Name = "ForceSensor" + i;
end
input(7).Name = "MotorPosition";

% Load the calibration matrix for the force transducer
load("cal_FT21128.mat");

% Create folder for record-keeping
date_string = string(datetime("now", "Format", "yyyy_MM_dd"));
if exist(date_string, "dir")
    disp("Experiment will overwrite data. Press ENTER to continue...");
    pause;
    rmdir(date_string, 's');
end
mkdir(date_string);

% Column names
names = ["F_x" "F_y" "F_z" "M_x" "M_y" "M_z"];

% Wait for DAQ setup to stabilize
pause(1);

% disp("Calibrating stopping distance. Press ENTER to begin...");
% pause;

% CAL_SPEED = 0.05; % m/s
% END = 0.2; % m
% prev = read(daq_obj);
% start(daq_obj);
% cal_output = DTOV * (prev.MotorPosition : CAL_SPEED / SRATE : END);
% write(daq_obj, cal_output');

% while true
%     pause(0.1);
%     curr = read(daq_obj);
%     if abs(curr.MotorPosition - prev.MotorPosition) / DTOV < 0.001
%         break;
%     end
%     prev = curr;
% end
% 
% stop(daq_obj);
% ground = curr(7) - input("Enter distance from ground plane (cm): ") / 100;

est_time = seconds(length(CFS) * length(SDS) * length(AS) * ...
    ((DATA_CYCLES + 2 * RAMP_CYCLES) * sum(1 ./ FS) + OFFSET_DURATION * length(FS)));
est_time.Format = 'hh:mm:ss';
est_elapsed = seconds(0);
est_elapsed.Format = 'hh:mm:ss';

h = waitbar(0, "Initializing...", "Name", "Dynamic Testing");
tic

% ACQUIRE DATA
for CF = CFS
    for SD = SDS
        for F = FS
            for A = AS
                case_name = sprintf("CF%d_SD%.1f_F%.1f_A%.1f", CF, SD * 100, F, A * 100);
                disp("Running " + case_name);

                actual_elapsed = seconds(toc);
                actual_elapsed.Format = 'hh:mm:ss';
                message = sprintf("Estimated execution time: %s\nElapsed time: %s", est_time, actual_elapsed);
                waitbar(est_elapsed / est_time, h, message);
                
                % Move to starting position
                % target = ground + A + SD;
                % disp(['Moving to ' (num2str(target) * 100) ' cm...']);
                % pause(1);
                % write(daq_obj, target * DTOV);
                % pause(3);

                % Gather data
                [time, forces, motor_position] = ...
                    dynamic_operation(CF, F, A, DATA_CYCLES, RAMP_CYCLES, OFFSET_DURATION, DTOV, daq_obj, cal_mat);
                
                % Save data
                filename = fullfile(date_string, case_name + '.mat');
                save(filename, "time", "forces", "motor_position");
                disp(['Data saved to: ' filename]);

                % Preliminary analysis
                mean_forces = mean(forces);
                std_forces = std(forces);

                disp("Measurements: mean (stdev)");
                for i = 1:6
                    fprintf("%s: %.2f (%.2f)\n", names(i), mean_forces(i), std_forces(i));
                end

                est_elapsed = est_elapsed + seconds((DATA_CYCLES + 2 * RAMP_CYCLES) * (1 / F) + OFFSET_DURATION);
            end
        end
    end
end