function [time, forces, measured, target] = dynamic_operation(CF, shift, F, A, data_cyc, ramp_cyc, offset_dur, DTOV, daq_obj, cal_mat)
    % -----------------------------------------------------------------------
    % Data Gathering Code for Dynamic Quadrotor Experiments
    % -----------------------------------------------------------------------
    
    % EXPERIMENT EXECUTION
    SRATE = daq_obj.Rate;
    disp("Zeroing output.");
    tare_output = DTOV * (shift + zeros(offset_dur * SRATE, 1));
    tare_inputs = readwrite(daq_obj, tare_output, "OutputFormat", "Matrix");

    % Calculate channel biases
    tare_voltages = mean(tare_inputs);

    if CF ~= 0
        disp("Starting Crazyflie.");
        run_drone(CF);
        pause(1);
    end

    target = shift + generate_profile(data_cyc, F, SRATE, ramp_cyc, A);
    data_output = DTOV * target;

    disp("Collecting data.");
    [data_inputs, time, ~] = readwrite(daq_obj, data_output', "OutputFormat", "Matrix");
    disp("Data collected.");
    
    if CF ~= 0
        disp("Stopping Crazyflie.")
        run_drone(0);
    end

    % DATA EXTRACTION
    disp("Extracting data.");
    row_start = floor(ramp_cyc/F*SRATE) + 1;
    rows = floor(data_cyc/F*SRATE);
    data_voltages = data_inputs(row_start : row_start + rows - 1, :);
    time = time(1 : rows);
    target = target(row_start : row_start + rows - 1);

    measured = data_voltages(:, 7) / DTOV;
    sensor_voltages = data_voltages(:, 1:6) - tare_voltages(:, 1:6);
    forces = (cal_mat * sensor_voltages')'; % Conversion to forces and moments
end

function position = generate_profile(data_cycles, traverse_freq, sampling_freq, ramp_cycles, amplitude)
    % -----------------------------------------------------------------------
    % % Generates a Ramping Waveform Using the Given Parameters
    % -----------------------------------------------------------------------

    total_cycles = data_cycles + ramp_cycles * 2; % Total cycles
    duration = total_cycles / traverse_freq; % Waveform duration, s
    pts_per_cycle = 1 / traverse_freq * sampling_freq; % Points per cycle

    time = 0 : 1/sampling_freq : duration - 1/sampling_freq; % Time vector
    position = amplitude * sin(2 * pi * traverse_freq * time); % Base waveform

    % Modulate ends using sinusoidal multiplier
    pts_ramp = floor(pts_per_cycle * ramp_cycles); % Number of points to be modulated on either end
    multiplier = 0.5 * (1 - cos(pi * (0 : 1/pts_ramp : 1)));
    position(1 : pts_ramp+1) = position(1 : pts_ramp+1) .* multiplier;
    position(end-pts_ramp : end) = position(end-pts_ramp : end) .* fliplr(multiplier);
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