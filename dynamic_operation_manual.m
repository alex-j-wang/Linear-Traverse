function [time, forces, motor_position] = dynamic_operation_manual(F, A, DTOV, daq_obj, cal_mat)
    % -----------------------------------------------------------------------
    % Data Gathering Code for Dynamic Quadrotor Experiments
    % -----------------------------------------------------------------------
    
    % CONSTANT PARAMETERS
    DATA_CYCLES = 40; % Cycles of data for phase averaging

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
    fprintf("Run traverse at F = %f, A = %f. Press ENTER when ready.", F, A);
    pause()
    
    disp("Collecting data...");
    duration = DATA_CYCLES / traverse_freq; % Waveform duration, s
    time = 0 : 1/sampling_freq : duration;
    data_inputs = read(daq_obj, length(time));
    system('ssh anoop@138.16.161.135 ./throttle.sh 0');

    % DATA EXTRACTION
    disp("Extracting data...");
    data_voltages = data_inputs(RAMP_CYCLES*SRATE : end-RAMP_CYCLES*SRATE, :);
    motor_position = data_voltages(:, 7) / DTOV;
    sensor_voltages = data_voltages(:, 1:6) - tare_voltages;
    forces = (cal_mat * sensor_voltages')'; % Conversion to forces and moments

    disp("Data collection complete.");
end