function [time, forces, motor_position] = dynamic_operation(F, A, DTOV, daq_obj, cal_mat)
    % -----------------------------------------------------------------------
    % Data Gathering Code for Dynamic Quadrotor Experiments
    % -----------------------------------------------------------------------
    
    % CONSTANT PARAMETERS
    DATA_CYCLES = 40; % Cycles of data for phase averaging
    RAMP_CYCLES = 4; % Cycles for ramping up and down

    OFFSET_DURATION = 10; % Duration for zeroing force transducer, s
    SRATE = daq_obj.Rate; % Data sampling rate, Hz

    % EXPERIMENT EXECUTION
    disp("Zeroing output...");
    tare_output = zeros(OFFSET_DURATION * SRATE, 1);
    tare_inputs = readwrite(daq_obj, tare_output, "OutputFormat", "Matrix");

    % Calculate channel biases
    tare_voltages = mean(tare_inputs);

    disp("Starting Crazyflie...");
    pause(1)
    system(['ssh anoop@138.16.161.135 ./throttle.sh ' CF]);
    pause(3)
    
    disp("Generating voltage profile...");
    [time, position] = generate_profile(DATA_CYCLES, F, SRATE, RAMP_CYCLES, A);
    data_output = DTOV * position;

    disp("Collecting data...");
    data_inputs = readwrite(daq_obj, data_output, "OutputFormat", "Matrix");
    system('ssh anoop@138.16.161.135 ./throttle.sh 0');

    % DATA EXTRACTION
    disp("Extracting data...");
    data_voltages = data_inputs(RAMP_CYCLES*SRATE : end-RAMP_CYCLES*SRATE, :);
    motor_position = data_voltages(:, 7) / DTOV;
    sensor_voltages = data_voltages(:, 1:6) - tare_voltages;
    forces = (cal_mat * sensor_voltages')'; % Conversion to forces and moments

    disp("Data collection complete.");
end

function [time, position] = generate_profile(data_cycles, traverse_freq, sampling_freq, ramp_cycles, amplitude)
    % -----------------------------------------------------------------------
    % % Generates a Ramping Waveform Using the Given Parameters
    % -----------------------------------------------------------------------

    total_cycles = data_cycles + ramp_cycles * 2; % Total cycles
    duration = total_cycles / traverse_freq; % Waveform duration, s
    pts_per_cycle = 1 / traverse_freq * sampling_freq; % Points per cycle

    time = 0 : 1/sampling_freq : duration; % Time vector
    position = amplitude * sin(2 * pi * traverse_freq * time); % Base waveform

    % Modulate ends using sinusoidal multiplier
    pts_ramp = round(pts_per_cycle * ramp_cycles); % Number of points to be modulated on either end
    multiplier = 0.5 * (1 - cos(pi * (0 : 1/pts_ramp : 1)));
    position(1 : pts_ramp) = position(1 : pts_ramp) .* multiplier;
    position(end-pts_ramp+1 : end) = position(end-pts_ramp+1 : end) .* fliplr(multiplier);
end