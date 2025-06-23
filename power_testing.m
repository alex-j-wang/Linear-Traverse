% -------------------------------------------------------------------------
% Minimal power example
% -------------------------------------------------------------------------

clear; clc; close all hidden;

% Test parameters
CFS = [10 20 30 40]; % Crazyflie throttle, %

% DAQ setup
daq_obj = Config.initialize('TargetPosition', 'MeasuredPosition');

% Acquire data
for CF = CFS
    % Gather data
    duration = 5;
    profile = zeros(duration * Config.SRATE, 1);

    if CF ~= 0
        disp('Starting Crazyflie.');
        Process.run_drone(CF);
        pause(5);
    end
    
    disp('Collecting data.');
    [data, time] = Process.conv_readwrite(daq_obj, profile, 1000, Config.Position);
    disp('Data collected.');

    if CF ~= 0
        disp('Stopping Crazyflie.')
        Process.run_drone(0);
        pause(CF / 20);
    end

    cf_voltage = data(:, 7);
    cf_current = data(:, 8);

    disp([CF mean(cf_voltage) mean(cf_current)]);
end
