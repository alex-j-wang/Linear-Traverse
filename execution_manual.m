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

OFFSET_DURATION = 10; % Duration for zeroing force transducer, s

% ACQUIRE DATA
for F = 0.3:0.3:1 % Traverse frequency, Hz
    for A = 0.025:0.025:0.1 % Traverse amplitude, m  
        disp("Zeroing output...");
        tare_output = zeros(OFFSET_DURATION * SRATE, 1);
        tare_inputs = readwrite(daq_obj, tare_output, "OutputFormat", "Matrix");

        % Calculate channel biases
        tare_voltages = mean(tare_inputs);
        
        fprintf("Run traverse at F = %.3f, A = %.3f. Press ENTER when ready.\n", F, A);
        pause()

        for CF = 75 % Crazyflie throttle, %
            % Gather data
            [time, forces, motor_position] = dynamic_operation_manual(CF, F, DTOV, daq_obj, cal_mat, tare_voltages);
            
            % Save data
            case_name = sprintf("CF%d_F%.1f_A%.1f", CF, F, A * 100);
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
        fprintf("Stop traverse. Press ENTER when ready.\n");
        pause()
    end
end