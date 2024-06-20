clear; clc; close all;

% DAQ setup
SRATE = 20000; % Data sampling rate, Hz
DTOV = 1 / .02; % Conversion factor from distance to voltage, V/m

disp("Setting up DAQ...");
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
date_string = datetime("now", "Format", "yyyy_MM_dd_HH_mm_ss");
if exist(date_string, "dir")
    disp("Experiment will overwrite data. Press enter to continue...");
    pause;
    rmdir(date_string, 's');
end
mkdir(date_string);

% Column names
names = ["F_x" "F_y" "F_z" "M_x" "M_y" "M_z"];

% Wait for DAQ setup to stabilize
pause(1);

disp("Calibrating stopping distance. Press ENTER to begin...");
pause;

CAL_SPEED = -0.05; % m/s
END = 0.2; % m
prev = read(daq_obj);
start(daq_obj);
cal_output = DTOV * (prev(7) : CAL_SPEED / SRATE : END);
write(daq_obj, cal_output);

while true
    pause(0.1);
    curr = read(daq_obj, "OutputFormat", "Matrix");
    if abs(curr(7) - prev(7)) / DTOV < 0.001
        break;
    end
    prev = curr;
end

stop(daq_obj);
ground = curr(7) - input("Enter distance from ground plane (cm): ") / 100;

% ACQUIRE DATA
for CF = [0 25 50 75] % Crazyflie throttle, %
    for SD = [0.5 1 2 5 10] / 100 % Stopping distance, m
        for F = 0.3:0.1:1 % Traverse frequency, Hz
            for A = 0.025:0.025:0.1 % Traverse amplitude, m
                    
                % Move to starting position
                target = ground + A + SD;
                disp(['Moving to ' num2str(target) ' m...']);
                pause(1);
                write(daq_obj, target * DTOV);
                pause(1);

                % Gather data
                [time, forces, motor_position] = dynamic_operation_manual(F, A, DTOV, daq_obj, cal_mat);
                
                % Save data
                case_name = sprintf("CF%d_SD%d_F%d_A%d", CF, SD * 100, F, A * 100);
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

                % Plot data
                figure("Position", [100, 100, 800, 600]);
                for i = 1:6
                    subplot(3, 2, i);
                    plot(time, forces(:, i), '-', "LineWidth", 1.5);
                    xlabel("Time (s)");
                    ylabel(names(i));
                    if i <= 3
                        title(['Force in ' char('X' + i - 1) ' Direction']);
                    else
                        title(['Moment about ' char('X' + i - 4) ' Axis']);
                    end
                end
                sgtitle("Preliminary Data", "FontWeight", "bold", "FontSize", 18);
            end
        end
    end
end