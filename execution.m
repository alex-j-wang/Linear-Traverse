% -------------------------------------------------------------------------
% Script to run experiments and save dynamic test data
% -------------------------------------------------------------------------

clear; clc; close all hidden;

% Test parameters
CFS = 50;   % Crazyflie throttle, %
TPOS = 1.1; % Traverse position selection
switch TPOS
    case 1.1
        SDS = Config.L / 1000 * [1 1.5 2 3]; % Stopping distance, m
        AS = Config.L / 1000 * [0.5 1 2 3];  % Traverse amplitude, m
    case 1.2
        SDS = Config.L / 1000 * 1.5;  % Stopping distance, m
        AS = Config.L / 1000 * 3.5; % Traverse amplitude, m
    case 2
        SDS = Config.L / 1000 * 10.5; % Stopping distance, m
        AS = Config.L / 1000 * 3.5; % Traverse amplitude, m
    case 3
        SDS = Config.L / 1000 * 19.5; % Stopping distance, m
        AS = Config.L / 1000 * 3.5; % Traverse amplitude, m
    case 4
        SDS = Config.L / 1000 * 28.5; % Stopping distance, m
        AS = Config.L / 1000 * 3.5; % Traverse amplitude, m
    case 5
        SDS = Config.L / 1000 * 37.5; % Stopping distance, m
        AS = Config.L / 1000 * 3.5; % Traverse amplitude, m
    otherwise
        error('Invalid traverse position selection.');
end
FS = [0.2 0.5 0.75 1]; % Traverse frequency, Hz
YAW = 0;
UPPER_CF = 'CF81'; % Disabled during lower hover normalization
LOWER_CF = 'CF80'; % Disabled during upper hover normalization

% Load force transducer calibration matrices
lower_cal = load(['cal_' Config.LOWER_FT '.mat'], 'cal_mat').('cal_mat');
upper_cal = load(['cal_' Config.UPPER_FT '.mat'], 'cal_mat').('cal_mat');

% DAQ setup
daq_obj = Config.initialize();

% Create folder for record-keeping
data_folder = fullfile('Data', [char(datetime('now', 'Format', 'yyyy_MM_dd')) '_DYN']);
if ~exist(data_folder, 'dir')
    mkdir(data_folder);
end

% Warn about overwriting data
overwritten = [];
for CF = CFS
    for SD = SDS
        for F = FS
            for A = AS
                case_name = sprintf('CF%g_SD%g_F%g_A%g', CF, SD * 100, F, A * 100);
                filename = fullfile(data_folder, [case_name '.mat']);
                if isfile(filename)
                    overwritten = [overwritten; string(filename)]; %#ok<AGROW>
                end
            end
        end
    end
end

if ~isempty(overwritten)
    disp("The following file(s) will be overwritten:");
    Config.print_tree(overwritten);
    if ~strcmpi(input('Do you want to continue? (y/n): ', 's'), 'y')
        disp('Execution aborted.');
        return;
    end
end

% Wait for DAQ setup to stabilize
disp('Ensure traverse is at zero position. Press ENTER to continue...');
pause;

position = 0;
position = Process.gradual_move(daq_obj, position, -0.125);
ground = position - input('Enter distance from ground plane (cm): ') / 100;

% Encoder calibration
disp('Calibrating encoder.');
[position, encoder] = Process.gradual_move(daq_obj, position, 0.125);
lpi = double(encoder(1) - encoder(end)) / (0.25 * 100 / 2.54);
fprintf('Encoder calibration: %.1f lines per inch.\n', lpi);

% Hover throttle calibration
disp('Checking hover thrust.');
hover_throttle = Config.get_hover;
cmin = 1e-3;
cmax = 5;

[data, timestamp] = dynamic_operation(hover_throttle, 0.125, 1/3, 0, daq_obj, lpi, UPPER_CF);
voltages = data{:, Config.LOWER_FT_CH};
forces = mean(Config.lower_to_world * lower_cal * voltages', 2);

lower = struct( ...
    'timestamp', timestamp, ...
    'thrust', forces(3), ...
    'voltage', mean(data.LowerVoltage), ...
    'current', mean(data.LowerCurrent(data.LowerCurrent >= cmin & data.LowerCurrent <= cmax)) ...
    );

[data, timestamp] = dynamic_operation(hover_throttle, 0.125, 1/3, 0, daq_obj, lpi, LOWER_CF);
voltages = data{:, Config.UPPER_FT_CH};
forces = mean(Config.upper_to_world(YAW) * upper_cal * voltages', 2);

upper = struct( ...
    'timestamp', timestamp, ...
    'thrust', forces(3), ...
    'voltage', mean(data.UpperVoltage), ...
    'current', mean(data.UpperCurrent(data.UpperCurrent >= cmin & data.UpperCurrent <= cmax)) ...
    );

save(fullfile(data_folder, 'calibration.mat'), 'hover_throttle', 'lower', 'upper', 'lpi');
Process.alert_slack(sprintf('[T%g] %g N, %g V, %g A (lower) | %g N, %g V, %g A (upper)', ...
    hover_throttle, lower.thrust, lower.voltage, lower.current, upper.thrust, upper.voltage, upper.current));

% Estimate execution time
est_time = seconds(length(CFS) * length(SDS) * length(AS) * ...
    (Config.TOTAL_CYCLES * sum(1 ./ FS) + 2 * Config.OFFSET_DURATION * length(FS)));
est_time.Format = 'hh:mm:ss';
est_elapsed = seconds(0);
est_elapsed.Format = 'hh:mm:ss';

% Create waitbar
h = uifigure('Name', 'Dynamic Testing');
d = uiprogressdlg(h, 'Title', 'Dynamic Testing', 'Cancelable', 'on', 'CancelText', '️️️️⏸');

start_time = tic;

% Acquire data
for CF = CFS
    for SD = SDS
        for F = FS
            for A = AS
                case_name = sprintf('CF%g_SD%g_F%g_A%g', CF, SD * 100, F, A * 100);
                disp(['Running <strong>' strrep(case_name, '_', ' ') '</strong>.']);

                % Update waitbar
                actual_elapsed = seconds(toc(start_time));
                actual_elapsed.Format = 'hh:mm:ss';
                est_remaining = est_time - est_elapsed;
                est_remaining.Format = 'hh:mm:ss';
                message = sprintf('Estimated time: %s / %s (%sR)\nElapsed time: %s\nCase: %s', ...
                    est_elapsed, est_time, est_remaining, actual_elapsed, strrep(case_name, '_', ' '));
                d.Value = est_elapsed / est_time;
                d.Message = message;

                % Move to starting position
                shift = ground + A + SD - Config.H / 1000;
                position = Process.gradual_move(daq_obj, position, shift);
                pause(1);

                % Gather data
                data = dynamic_operation(CF, shift, F, A, daq_obj, lpi);

                % Save data
                filename = fullfile(data_folder, [case_name '.mat']);
                save(filename, 'data');
                fprintf('Data saved to <strong>%s</strong>.\n', filename);

                if d.CancelRequested
                    disp('Execution paused.');
                    set(d, 'CancelRequested', false, 'CancelText', '▶');
                    waitfor(d, 'CancelRequested', true);
                    disp('Execution resuming.');
                    set(d, 'CancelRequested', false, 'CancelText', '⏸');
                end

                est_elapsed = est_elapsed + seconds(Config.TOTAL_CYCLES * (1 / F) + 2 * Config.OFFSET_DURATION);
            end
        end
    end
end

actual_elapsed = seconds(toc(start_time));
actual_elapsed.Format = 'hh:mm:ss';
message = sprintf('Estimated time: %s / %s\nElapsed time: %s', est_elapsed, est_time, actual_elapsed);
d.Value = 1;
d.Message = message;
position = Process.gradual_move(daq_obj, position, 0);

Process.alert_slack(['Dynamic testing for ' data_folder ' completed in ' char(actual_elapsed) '.']);
pause(3);
close(h);
