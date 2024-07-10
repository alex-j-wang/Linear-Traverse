function [time, forces, target, measured] = dynamic_operation(CF, shift, F, A, daq_obj, cal_mat, mode)
    % -----------------------------------------------------------------------
    % Data Gathering Code for Dynamic Quadrotor Experiments
    % -----------------------------------------------------------------------
    
    % EXPERIMENT EXECUTION
    disp("Zeroing output.");
    tare_output = repmat(shift, Config.OFFSET_DURATION * Config.SRATE, 1);
    tare_inputs = mean(readposwritepos(daq_obj, tare_output));

    if CF ~= 0
        disp("Starting Crazyflie.");
        run_drone(CF);
        pause(1);
    end

    profile = shift + generate_profile(F, A);

    disp("Collecting data.");
    if mode == Config.Position
        [data, time] = readposwritepos(daq_obj, profile);
    else
        [data, time] = readcurrwritepos(daq_obj, profile);
    end
    disp("Data collected.");
    
    if CF ~= 0
        disp("Stopping Crazyflie.")
        run_drone(0);
    end

    % DATA EXTRACTION
    disp("Extracting data.");
    row_start = floor(Config.RAMP_CYCLES / F * Config.SRATE) + 1;
    rows = floor(Config.DATA_CYCLES / F * Config.SRATE);
    data = data(row_start : row_start + rows - 1, :);
    time = time(1 : rows);

    target = data(:, 7);
    measured = data(:, 8);
    sensor_voltages = data(:, 1:6) - tare_inputs(:, 1:6);
    forces = (cal_mat * sensor_voltages')'; % Conversion to forces and moments
end

function position = generate_profile(traverse_freq, amplitude)
    % -----------------------------------------------------------------------
    % % Generates a Ramping Waveform Using the Given Parameters
    % -----------------------------------------------------------------------

    duration = Config.TOTAL_CYCLES / traverse_freq; % Waveform duration, s
    pts_per_cycle = 1 / traverse_freq * Config.SRATE; % Points per cycle

    time = 0 : 1 / Config.SRATE : duration - 1 / Config.SRATE; % Time vector
    position = amplitude * sin(2 * pi * traverse_freq * time); % Base waveform

    % Modulate ends using sinusoidal multiplier
    pts_ramp = floor(pts_per_cycle * Config.RAMP_CYCLES); % Number of points to be modulated on either end
    multiplier = 0.5 * (1 - cos(pi * (0 : 1 / pts_ramp : 1)));
    position(1 : pts_ramp + 1) = position(1 : pts_ramp + 1) .* multiplier;
    position(end - pts_ramp : end) = position(end - pts_ramp : end) .* fliplr(multiplier);
    position = position';
end

function run_drone(throttle)
    runtime = java.lang.Runtime.getRuntime();
    process = runtime.exec("ssh anoop@172.18.139.96 ./throttle.sh " + throttle);
    process.waitFor(15, java.util.concurrent.TimeUnit.SECONDS);
    if process.isAlive()
        process.destroyForcibly();
        disp("Unable to contact drone. Manually set " + throttle + " throttle.");
        disp("Press ENTER when ready...");
        pause();
    end
end