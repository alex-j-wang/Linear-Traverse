% -------------------------------------------------------------------------
% Script to run several trials and save static test data
% -------------------------------------------------------------------------

clear; clc; close all hidden;

% Test parameters
TRIALS = 10;
CFS = 54.275; % Crazyflie throttle, %
SDS = [0.035 0.04 0.07 0.10 0.13 0.18 0.23 0.28];  % Stopping distance, m
F = 1;
A = 0;

% DAQ setup
daq_obj = Config.initialize();

% Create folder for record-keeping
data_folder = fullfile('Data', [char(datetime('now', 'Format', 'yyyy_MM_dd')) '_STAT']);
if exist(data_folder, 'dir')
    disp('Experiment may overwrite data. Press ENTER to continue...');
    pause;
else
    mkdir(data_folder);
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

% Estimate execution time
est_time = seconds(TRIALS * length(CFS) * length(SDS) * ...
    (Config.TOTAL_CYCLES / F + 2 * Config.OFFSET_DURATION));
est_time.Format = 'hh:mm:ss';
est_elapsed = seconds(0);
est_elapsed.Format = 'hh:mm:ss';

% Create waitbar
h = uifigure('Name', 'Static Testing');
d = uiprogressdlg(h, 'Title', 'Static Testing', 'Cancelable', 'on', 'CancelText', '️️️️⏸');

tic

% Acquire data
for TRIAL = 1:TRIALS
    trial_folder = fullfile(data_folder, ['T' num2str(TRIAL, "%02.f")]);
    if exist(trial_folder, 'dir')
        disp('Experiment may overwrite data. Press ENTER to continue...');
        pause;
    else
        mkdir(trial_folder);
    end
    for CF = CFS
        for SD = SDS
            case_name = sprintf('CF%g_SD%g_F%g_A%g', CF, SD * 100, F, A * 100);
            disp(['Running <strong>T' num2str(TRIAL) ' ' strrep(case_name, '_', ' ') '</strong>.']);
    
            % Update waitbar
            actual_elapsed = seconds(toc);
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
            [time, voltages, tare_start, tare_end, audio, pos_encoder, cf_current] = ...
                dynamic_operation(CF, shift, F, A, daq_obj, lpi);
    
            % Save data
            filename = fullfile(trial_folder, [case_name '.mat']);
            save(filename, 'time', 'voltages', 'tare_start', 'tare_end', 'audio', 'pos_encoder', 'cf_current');
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

actual_elapsed = seconds(toc);
actual_elapsed.Format = 'hh:mm:ss';
message = sprintf('Estimated time: %s / %s\nElapsed time: %s', est_elapsed, est_time, actual_elapsed);
d.Value = 1;
d.Message = message;
position = Process.gradual_move(daq_obj, position, 0);

pause(3);
close(h);