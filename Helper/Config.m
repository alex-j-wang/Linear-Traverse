% --------------------------------------------------------------------
% Class storing constant values, enumerations, and setup methods
% --------------------------------------------------------------------

classdef Config
    properties (Constant = true)
        W = 0.032 * 9.8; % Weight of Crazyflie, N
        L = 35; % Motor-center distance, mm
        
        DATA_CYCLES = 20; % Cycles of data for phase averaging
        RAMP_CYCLES = 4; % Cycles for ramping up and down
        TOTAL_CYCLES = Config.DATA_CYCLES + 2 * Config.RAMP_CYCLES; % Total cycles
        
        OFFSET_DURATION = 1; % Duration for zeroing force transducer, s
        SHIFT_SPEED = 0.05; % m/s
        CAL_SAMPLES = 3000; % Samples for position calibration

        SRATE = 20000; % Data sampling rate, Hz
        DTOV = 1 / 0.02; % Conversion factor from distance to voltage, V/m
        VTOD = 0.02; % Conversion factor from voltage to distance, m/V
        VTOI = 0.1; % Conversion factor from voltage to current, A/V
        
        LPI = 3933.571; % Encoder lines per inch
        NBITS = 32; % Encoder channel resolution

        TICKSHIFT = Config.SHIFT_SPEED / Config.SRATE; % Meters to shift per tick
        NAMES = ["F_x" "F_y" "F_z" "M_x" "M_y" "M_z"]; % Labels for plots and outputs
        FORCES = ["Total" "Intertial" "Lift"];
        SSH = "anoop@172.18.139.146";
    end

    enumeration
        Position, Current
    end

    methods(Static)
        function daq_obj = initialize(ch6, ch7)
            % DAQ setup
            disp("Setting up DAQ.");
            daq_obj = daq("ni");
            daq_obj.Rate = Config.SRATE;
            
            % Output channel (motor voltage)
            output = addoutput(daq_obj, "Dev2", "ao0", "Voltage");
            output.Name = "voutput";
            
            % Input channels (force sensor and position)
            input_channels = addinput(daq_obj, "Dev2", 0:7, "Voltage");
            for i = 1:6
                input_channels(i).Name = "ForceSensor" + i;
            end
            input_channels(7).Name = ch6;
            input_channels(8).Name = ch7;

            % Input channel (position encoder)
            encoder = addinput(daq_obj, "Dev2", "ctr0", "Position");
            encoder.EncoderType = "X4";
            encoder.ZResetEnable = 0;
            encoder.ZResetCondition = "BothLow";
            encoder.ZResetValue = 0;
            encoder.Name = 'Encoder';
        end
    end
end