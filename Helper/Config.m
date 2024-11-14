% --------------------------------------------------------------------
% Class storing constant values, enumerations, and setup methods
% --------------------------------------------------------------------

classdef Config
    properties (Constant = true)
        W = 0.032 * 9.8; % Weight of Crazyflie, N
        L = 32.5;          % Motor-center distance, mm
        FCM = 10;       % Cutoff frequency multiplier
        
        DATA_CYCLES = 40; % Cycles of data for phase averaging
        RAMP_CYCLES = 4;  % Cycles for ramping up and down
        TOTAL_CYCLES = Config.DATA_CYCLES + 2 * Config.RAMP_CYCLES; % Total cycles
        
        OFFSET_DURATION = 10; % Duration for zeroing force transducer at each end, s
        SHIFT_SPEED = 0.05;   % Speed while shifting, m/s
        CAL_SAMPLES = 3000;   % Samples for position calibration

        SRATE = 20000;   % Data sampling rate, Hz
        DTOV = 1 / 0.02; % Conversion factor from distance to voltage, V/m
        VTOD = 0.02;     % Conversion factor from voltage to distance, m/V
        VTOI = 0.25;     % Conversion factor from voltage to current, A/V
        
        LPI = 3933.571; % Approximate encoder lines per inch
        NBITS = 32;     % Encoder channel resolution

        TICKSHIFT = Config.SHIFT_SPEED / Config.SRATE;                % Meters to shift per tick
        NAMES = ["F_x" "F_y" "F_z" "M_x" "M_y" "M_z"];                % Labels for plots and outputs
        BOXES = ["Total" "Inertial" "Lift" "Tare" "Lock" "Equalize"]; % Available force plots
        SSH = 'anoop@172.18.141.21';                                  % Linux computer SSH address
        SENSOR = 'FT9042';                                            % Nano17 serial number
    end

    enumeration
        Position, Current % Modes for voltage conversion
    end

    methods(Static)
        function daq_obj = initialize(ch6, ch7)
            % INITIALIZE  Initialize a DAQ object with input and output channels
            disp('Setting up DAQ.');
            daq_obj = daq('ni');
            daq_obj.Rate = Config.SRATE;
            
            % Output channel (motor voltage)
            output = addoutput(daq_obj, 'Dev2', 'ao0', 'Voltage');
            output.Name = 'voutput';
            
            % Input channels (force sensor and position)
            input_channels = addinput(daq_obj, 'Dev2', 0:7, 'Voltage');
            for i = 1:6
                input_channels(i).Name = "ForceSensor" + i;
            end
            if nargin == 2
                input_channels(7).Name = ch6;
                input_channels(8).Name = ch7;
            else
                input_channels(7).Name = 'TargetPosition';
                input_channels(8).Name = 'MeasuredPosition';
            end

            % Input channel (position encoder)
            encoder_plus = addinput(daq_obj, 'Dev2', 'ctr0', 'Position');
            encoder_plus.EncoderType = 'X4';
            encoder_plus.ZResetEnable = 0;
            encoder_plus.ZResetCondition = 'BothLow';
            encoder_plus.ZResetValue = 0;
            encoder_plus.Name = 'EncoderPlus';

            encoder_minus = addinput(daq_obj, 'Dev2', 'ctr1', 'Position');
            encoder_minus.EncoderType = 'X4';
            encoder_minus.ZResetEnable = 0;
            encoder_minus.ZResetCondition = 'BothLow';
            encoder_minus.ZResetValue = 0;
            encoder_minus.Name = 'EncoderMinus';
        end
    end
end