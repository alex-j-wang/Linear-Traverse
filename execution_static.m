% -------------------------------------------------------------------------
% Script to run several trials and save static test data
% -------------------------------------------------------------------------

clear; clc; close all hidden;

% Test parameters
TRIALS = 3;
CFS = 50;
% TODO: refactor into switch case for each traverse position
NEAR = false;
if NEAR == true
    SDS = Config.L / 1000 * (1:1:9); % Stopping distance, m
else
    SDS = Config.L / 1000 * [8 9 11 13 15]; % Stopping distance, m
end
F = 1;
A = 0;
YAW = 0;
TRAV = 'CF81'; % Disabled during hover normalization
FT = 'CF80';

% Load the calibration matrix for the force transducer
load(['cal_' Config.SENSOR '.mat']);

% DAQ setup
daq_obj = Config.initialize();

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
            SD_name = SD;
            % TODO: more elegant way to distinguish duplicate case
            if NEAR == false && (SD == Config.L / 1000 * 8 || SD == Config.L / 1000 * 9)
                SD_name = SD_name + Config.L / 1000 * 0.25;
            end
            case_name = sprintf('CF%g_SD%g_F%g_A%g', CF, SD_name * 100, F, A * 100);
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
shift = ground + SDS(end) - Config.H / 1000;
position = Process.gradual_move(daq_obj, position, shift);
[~, voltages] = dynamic_operation(hover_throttle, shift, 4, 0, daq_obj, lpi, FT);
forces = mean(cal_mat * voltages', 2);
hover_thrust = forces(3);

save(fullfile(data_folder, 'calibration.mat'), 'hover_throttle', 'hover_thrust', 'lpi');
Process.alert_slack(sprintf('T%g -> %g N', hover_throttle, hover_thrust));

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
            SD_name = SD;
            % TODO: more elegant way to distinguish duplicate case
            if NEAR == false && (SD == Config.L / 1000 * 8 || SD == Config.L / 1000 * 9)
                SD_name = SD_name + Config.L / 1000 * 0.25;
            end
            case_name = sprintf('CF%g_SD%g_F%g_A%g', CF, SD_name * 100, F, A * 100);
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
            [time, voltages, tare_start, tare_end, motor_voltage, audio, pos_encoder, cf_current] = ...
                dynamic_operation(CF, shift, F, A, daq_obj, lpi);

            % Save data
            filename = fullfile(trial_folder, [case_name '.mat']);
            save(filename, 'time', 'voltages', 'tare_start', 'tare_end', 'motor_voltage', 'audio', 'pos_encoder', 'cf_current');
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
