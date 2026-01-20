% --------------------------------------------------------------------
% Class storing constant values, enumerations, and setup methods
% --------------------------------------------------------------------

classdef Config
    properties(Constant = true)
        W = 0.032 * 9.8; % Weight of Crazyflie, N
        L = 32.5;        % Motor-center distance, mm
        H = 29.65;       % Height of Crazyflie, mm
        U_i = sqrt((Config.L / 1000 * 9.81) / (2 * 1.293 * pi * (22.5 / 1000)^2));
        
        DATA_CYCLES = 40; % Cycles of data for phase averaging
        RAMP_CYCLES = 4;  % Cycles for ramping up and down
        TOTAL_CYCLES = Config.DATA_CYCLES + 2 * Config.RAMP_CYCLES; % Total cycles
        
        OFFSET_DURATION = 10; % Duration for zeroing force transducer at each end, s
        SHIFT_SPEED = 0.05;   % Speed while shifting, m/s
        CAL_SAMPLES = 3000;   % Samples for position calibration

        SRATE = 20000;   % Data sampling rate, Hz
        DTOV = 1 / 0.02; % Conversion factor from distance to voltage, V/m
        VTOD = 0.02;     % Conversion factor from voltage to distance, m/V
        
        LPI = 3933.571; % Approximate encoder lines per inch
        NBITS = 32;     % Encoder channel resolution

        LOWER_FT_CH = "LowerForce" + (1:6);               % Lower Nano17 channels
        UPPER_FT_CH = "UpperForce" + (1:6);               % Upper Nano17 channels
        FT_CH = [Config.LOWER_FT_CH, Config.UPPER_FT_CH]; % Combined Nano17 channels

        TICKSHIFT = Config.SHIFT_SPEED / Config.SRATE;                % Meters to shift per tick
        NAMES = ["F_x" "F_y" "F_z" "M_x" "M_y" "M_z"];                % Labels for plots and outputs
        BOXES = ["Total" "Inertial" "Lift" "Tare" "Lock" "Equalize"]; % Available force plots
        SSH = 'anoop@anoop-g3-3579.devices.brown.edu';                % Linux computer SSH address
        LOWER_FT = 'FT9042';                                          % Lower Nano17 serial number
        UPPER_FT = 'FT58251';                                         % Upper Nano17 serial number
        ESPCOM = 'COM10';                                             % ESP32 COM port
        BAUD = 115200;                                                % ESP32 baud rate
    end

    methods(Static)
        function set_hover(throttle)
            save(Config.disk_file, 'throttle');
        end

        function throttle = get_hover
            if isfile(Config.disk_file)
                load(Config.disk_file, 'throttle');
            else
                throttle = 50;
                Config.set_hover(throttle);
            end
        end

        function path = disk_file
            path = fullfile(tempdir, 'traverse.mat');
        end

        function daq_obj = initialize(out)
            % INITIALIZE  Initialize a DAQ object with input and output channels
            % If OUT is true, include output channel for motor voltage
            arguments
                out = true;
            end

            disp('Setting up DAQ.');
            daq_obj = daq('ni');
            daq_obj.Rate = Config.SRATE;
            
            % Output channel (motor voltage)
            if out
                output = addoutput(daq_obj, 'Dev4', "ao0", 'Voltage');
                output.Name = 'voutput';
            end

            % Lower Crazyflie input channels (force, voltage)
            lower = addinput(daq_obj, 'Dev4', 0:6, 'Voltage');
            for i = 1:6
                lower(i).Name = Config.LOWER_FT_CH(i);
            end
            lower(7).Name = 'LowerVoltage';

            % Upper Crazyflie input channels (force, voltage)
            upper = addinput(daq_obj, 'Dev4', 16:22, 'Voltage');
            for i = 1:6
                upper(i).Name = Config.UPPER_FT_CH(i);
            end
            upper(7).Name = 'UpperVoltage';
            
            % Microphone input channel
            microphone = addinput(daq_obj, 'Dev4', "ai7", 'Voltage');
            microphone.TerminalConfig = "SingleEnded";
            microphone.Name = 'Microphone';

            % Input channel (position encoder)
            encoder_plus = addinput(daq_obj, 'Dev4', 'ctr0', 'Position');
            encoder_plus.EncoderType = 'X4';
            encoder_plus.ZResetEnable = 0;
            encoder_plus.ZResetCondition = 'BothLow';
            encoder_plus.ZResetValue = 0;
            encoder_plus.Name = 'EncoderPlus';

            encoder_minus = addinput(daq_obj, 'Dev4', 'ctr1', 'Position');
            encoder_minus.EncoderType = 'X4';
            encoder_minus.ZResetEnable = 0;
            encoder_minus.ZResetCondition = 'BothLow';
            encoder_minus.ZResetValue = 0;
            encoder_minus.Name = 'EncoderMinus';
        end

        function print_tree(filepaths)
            % PRINT_TREE  Pretty-print a tree from a list of file paths
            filepaths = string(filepaths);
            parts = cellfun(@(f) strsplit(f, filesep), cellstr(filepaths), 'UniformOutput', false);
            Config.print_node(parts, '', 1);
        end

        function print_node(paths, prefix, level)
            % Get all unique items at current level
            items = unique(cellfun(@(x) x{level}, paths, 'UniformOutput', false), 'stable');

            for i = 1:numel(items)
                item = items{i};
                is_last = (i == numel(items));
                connector = Config.ternary(is_last, '└── ', '├── ');
                disp([prefix connector item]);

                matching = paths(cellfun(@(x) numel(x) >= level && strcmp(x{level}, item), paths));
                % Recurse if there are deeper levels
                if any(cellfun(@(x) numel(x), matching) > level)
                    new_prefix = [prefix Config.ternary(is_last, '    ', '│   ')];
                    Config.print_node(matching, new_prefix, level + 1);
                end
            end
        end

        function out = ternary(cond, a, b)
            if cond
                out = a;
            else
                out = b;
            end
        end

        function R = lower_to_world
            % LOWER_TO_WORLD  Rotation matrix from lower Nano17 to world frame
            % If BB represents two body frame column vectors (stacked vertically),
            % WW = R*BB represents the corresponding world frame vectors
            R = Config.rotz(90);
            R = blkdiag(R, R);
        end

        function R = upper_to_world(yaw)
            % UPPER_TO_WORLD  Rotation matrix from upper Nano17 to world frame
            % YAW is degrees turned ccw looking down the world Z-axis
            % If BB represents two body frame column vectors (stacked vertically),
            % WW = R*BB represents the corresponding world frame vectors
            R = Config.rotz(yaw) * Config.rotz(-90) * Config.roty(180);
            R = blkdiag(R, R);
        end

        function R = rotx(degrees)
            % ROTX  Create rotation matrix for rotation about the X-axis
            radians = deg2rad(degrees);
            R = [1 0 0; 0 cos(radians) -sin(radians); 0 sin(radians) cos(radians)];
        end

        function R = roty(degrees)
            % ROTY  Create rotation matrix for rotation about the Y-axis
            radians = deg2rad(degrees);
            R = [cos(radians) 0 sin(radians); 0 1 0; -sin(radians) 0 cos(radians)];
        end

        function R = rotz(degrees)
            % ROTZ  Create rotation matrix for rotation about the Z-axis
            radians = deg2rad(degrees);
            R = [cos(radians) -sin(radians) 0; sin(radians) cos(radians) 0; 0 0 1];
        end
    end
end