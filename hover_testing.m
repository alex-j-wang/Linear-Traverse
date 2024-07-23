% Load the calibration matrix for the force transducer
load(['cal_' Config.SENSOR '.mat']);

disp("Ensure traverse is at home position.");
pause;

% DAQ setup
daq_obj = Config.initialize("TargetPosition", "MeasuredPosition");

tare_output = zeros(Config.OFFSET_DURATION * Config.SRATE, 1);
disp("Taring output.");
tare_voltages = mean(Process.conv_readwrite(daq_obj, tare_output, lpi, Config.Position));
tare_voltages = tare_voltages(1:6);

throttles = 0:5:75;
forces_z = zeros(length(throttles));

for CF = throttles
    if CF ~= 0
        disp("Starting Crazyflie.");
        Process.run_drone(CF);
        pause(1);
    end

    profile = zeros(30 * Config.SRATE, 1);
    
    disp("Collecting data.");
    [data, time] = Process.conv_readwrite(daq_obj, profile, lpi, mode);
    disp("Data collected.");

    voltages = data(:, 1:6) - tare_voltages;
    forces = (cal_mat * voltages')'; % Conversion to forces and moments
    forces_z(CF / 5 + 1) = mean(forces(:, 3));
end

disp("Stopping Crazyflie.");
Process.run_drone(0);

format_plot("Normalized Force vs. Throttle", "Normalized Force", "Throttle (%)");
plot(throttles, forces_z / Config.W);
