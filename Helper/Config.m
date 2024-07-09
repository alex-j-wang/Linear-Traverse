classdef Config
    properties (Constant = true)
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

        TICKSHIFT = Config.SHIFT_SPEED / Config.SRATE; % Meters to shift per tick
    end
    enumeration
        Position, Current
    end
end