% -------------------------------------------------------------------------
% Script to run several trials and save static test data
% -------------------------------------------------------------------------

clear; clc; close all hidden;

% Test parameters
TRIALS = 3;
CFS = 50;
TPOS = 1; % Traverse position selection
switch TPOS
    case 1
        SDS = Config.L / 1000 * (1:1:9); % Stopping distance, m
    case 2
        SDS = Config.L / 1000 * (10:2:18); % Stopping distance, m
    case 3
        SDS = Config.L / 1000 * (19:4:27); % Stopping distance, m
    case 4
        SDS = Config.L / 1000 * (28:4:36); % Stopping distance, m
    case 5
        SDS = Config.L / 1000 * (37:4:45); % Stopping distance, m
    otherwise
        error('Invalid traverse position selection.');
end
F = 1;
A = 0;
YAW = 0;
UPPER_CF = 'CF81'; % Disabled during lower hover normalization
LOWER_CF = 'CF80'; % Disabled during upper hover normalization

% Load force transducer calibration matrices
lower_cal = load(['cal_' Config.LOWER_FT '.mat'], 'cal_mat').('cal_mat');
upper_cal = load(['cal_' Config.UPPER_FT '.mat'], 'cal_mat').('cal_mat');

% DAQ setup
daq_obj = Config.initialize;

% Create folder for record-keeping
data_folder = fullfile('Data', [char(datetime('now', 'Format', 'yyyy_MM_dd')) '_Y' num2str(YAW) '_STAT']);
if ~exist(data_folder, 'dir')
    mkdir(data_folder);
end

% Warn about overwriting data
overwritten = [];
for TRIAL = 1:TRIALS
    trial_folder = fullfile(data_folder, ['T' num2str(TRIAL, "%02.f")]);
    for CF = CFS
        for SD = SDS
            case_name = sprintf('CF%g_SD%g_TP%g_F%g', CF, SD * 100, TPOS, F);
            filename = fullfile(trial_folder, [case_name '.mat']);
            if isfile(filename)
                overwritten = [overwritten; string(filename)]; %#ok<AGROW>
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

[data, timestamp] = dynamic_operation(hover_throttle, shift, 1/3, 0, daq_obj, lpi, UPPER_CF);
voltages = data{:, Config.LOWER_FT_CH};
forces = mean(Config.lower_to_world * lower_cal * voltages', 2);

lower = struct( ...
    'timestamp', timestamp, ...
    'thrust', forces(3), ...
    'voltage', mean(data.LowerVoltage), ...
    'current', mean(data.LowerCurrent(data.LowerCurrent >= cmin & data.LowerCurrent <= cmax)) ...
    );

[data, timestamp] = dynamic_operation(hover_throttle, shift, 1/3, 0, daq_obj, lpi, LOWER_CF);
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
est_time = seconds(TRIALS * length(CFS) * length(SDS) * ...
    (Config.TOTAL_CYCLES / F + 2 * Config.OFFSET_DURATION));
est_time.Format = 'hh:mm:ss';
est_elapsed = seconds(0);
est_elapsed.Format = 'hh:mm:ss';

% Create waitbar
h = uifigure('Name', 'Static Testing');
d = uiprogressdlg(h, 'Title', 'Static Testing', 'Cancelable', 'on', 'CancelText', '️️️️⏸');

start_time = tic;

% Acquire data
for TRIAL = 1:TRIALS
    trial_folder = fullfile(data_folder, ['T' num2str(TRIAL, "%02.f")]);
    if ~exist(trial_folder, 'dir')
        mkdir(trial_folder);
    end
    for CF = CFS
        for SD = SDS
            case_name = sprintf('CF%g_SD%g_TP%g_F%g', CF, SD * 100, TPOS, F);
            disp(['Running <strong>T' num2str(TRIAL) ' ' strrep(case_name, '_', ' ') '</strong>.']);

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
            filename = fullfile(trial_folder, [case_name '.mat']);
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

actual_elapsed = seconds(toc(start_time));
actual_elapsed.Format = 'hh:mm:ss';
message = sprintf('Estimated time: %s / %s\nElapsed time: %s', est_elapsed, est_time, actual_elapsed);
d.Value = 1;
d.Message = message;
position = Process.gradual_move(daq_obj, position, 0);

Process.alert_slack(['Static testing for ' data_folder ' completed in ' char(actual_elapsed) '.']);
pause(3);
close(h);
