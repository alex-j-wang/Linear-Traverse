clear; clc; close all hidden;

% Load the calibration matrix for the force transducer
load(['cal_' Config.SENSOR '.mat']);

disp("Ensure traverse is at home position. Press ENTER to continue...");
pause;

% DAQ setup
daq_obj = Config.initialize("TargetPosition", "MeasuredPosition");

tare_output = zeros(Config.OFFSET_DURATION * Config.SRATE, 1);
disp("Taring output.");
tare_voltages = mean(readwrite(daq_obj, profile, "OutputFormat", "Matrix"));
tare_voltages = tare_voltages(1:6);

throttles = 0:5:75;
forces_z = zeros(1, length(throttles));
idx = 1;

for CF = throttles
    if CF ~= 0
        fprintf("Starting Crazyflie at %d throttle.\n", CF);
        Process.run_drone(CF);
        pause(1);
    end

    profile = zeros(30 * Config.SRATE, 1);
    
    disp("Collecting data.");
    data = readwrite(daq_obj, profile, "OutputFormat", "Matrix");
    disp("Data collected.");

    voltages = data(:, 1:6) - tare_voltages;
    forces = (cal_mat * voltages')'; % Conversion to forces and moments
    forces_z(idx) = mean(forces(:, 3));
    idx = idx + 1;
end

disp("Stopping Crazyflie.");
Process.run_drone(0);

Process.format_plot("Normalized Force vs. Throttle", "Throttle (%)", "Normalized Force");
plot(throttles, forces_z / Config.W);