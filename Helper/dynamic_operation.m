% ------------------------------------------------
% Function for gathering dynamic test data
% ------------------------------------------------

function [time, voltages, tare_voltages, target, measured, encoder] = dynamic_operation(CF, shift, F, A, daq_obj, mode)
    % DYNAMIC_OPERATION  Operates traverse and drone based on inputs to acquire data
    tare_output = repmat(shift, Config.OFFSET_DURATION * Config.SRATE, 1);
    disp("Taring output.");
    tare_start = mean(Process.conv_readwrite(daq_obj, tare_output, Config.Position));
    tare_start = tare_start(1:6);

    if CF ~= 0
        disp("Starting Crazyflie.");
        Process.run_drone(CF);
        pause(1);
    end

    profile = shift + generate_profile(F, A);

    disp("Collecting data.");
    [data, time] = Process.conv_readwrite(daq_obj, profile, mode);
    disp("Data collected.");

    disp("Taring output.");
    tare_end = mean(Process.conv_readwrite(daq_obj, tare_output, Config.Position));
    tare_end = tare_end(1:6);
    
    if CF ~= 0
        disp("Stopping Crazyflie.")
        Process.run_drone(0);
    end

    disp("Extracting data.");
    row_start = floor(Config.RAMP_CYCLES / F * Config.SRATE) + 1;
    rows = floor(Config.DATA_CYCLES / F * Config.SRATE);
    data = data(row_start : row_start + rows - 1, :);
    time = time(1 : rows);

    tare_voltages = (tare_start + tare_end) / 2;
    voltages = data(:, 1:6) - tare_voltages;
    target = data(:, 7);
    measured = data(:, 8);
    encoder = data(:, 9);
end

function position = generate_profile(traverse_freq, amplitude)
    % GENERATE_PROFILE  Generate a sinusoidal position profile with ramped ends
    duration = Config.TOTAL_CYCLES / traverse_freq;
    pts_per_cycle = 1 / traverse_freq * Config.SRATE;

    time = 0 : 1 / Config.SRATE : duration - 1 / Config.SRATE;
    position = amplitude * sin(2 * pi * traverse_freq * time); % Base waveform

    % Modulate ends using sinusoidal multiplier
    pts_ramp = floor(pts_per_cycle * Config.RAMP_CYCLES);
    multiplier = 0.5 * (1 - cos(pi * (0 : 1 / pts_ramp : 1)));
    position(1 : pts_ramp + 1) = position(1 : pts_ramp + 1) .* multiplier;
    position(end - pts_ramp : end) = position(end - pts_ramp : end) .* fliplr(multiplier);
    position = position';
end