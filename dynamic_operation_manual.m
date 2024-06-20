function [time, forces, motor_position] = dynamic_operation_manual(CF, F, DTOV, daq_obj, cal_mat, tare_voltages)
    % -----------------------------------------------------------------------
    % Data Gathering Code for Dynamic Quadrotor Experiments
    % -----------------------------------------------------------------------
    
    % CONSTANT PARAMETERS
    DATA_CYCLES = 20; % Cycles of data for phase averaging
    SRATE = daq_obj.Rate; % Data sampling rate, Hz

    % EXPERIMENT EXECUTION
    disp("Starting Crazyflie...");
    pause(1)
    system("ssh anoop@138.16.161.135 ./throttle.sh " + CF);

    disp("Collecting data...");
    duration = DATA_CYCLES / F; % Waveform duration, s
    time = 0 : 1/SRATE : duration;
    data_voltages = readwrite(daq_obj, zeros(length(time), 1), 'OutputFormat', 'Matrix');
    system("ssh anoop@138.16.161.135 ./throttle.sh 0");

    % DATA EXTRACTION
    disp("Extracting data...");
    motor_position = data_voltages(:, 7) / DTOV;
    sensor_voltages = data_voltages(:, 1:6) - tare_voltages(:, 1:6);
    forces = (cal_mat * sensor_voltages')'; % Conversion to forces and moments

    disp("Data collection complete.");
end