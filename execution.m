% -------------------------------------------------------------------------
% Script to run experiments and save dynamic test data
% -------------------------------------------------------------------------

clear; clc; close all hidden;

% Test parameters
CFS = 54.275; % Crazyflie throttle, %
SDS = [0.005 0.01 0.04 0.07]; % Stopping distance, m
FS = [0.2 0.5 0.75 1];  % Traverse frequency, Hz
AS = [.025 0.05 0.07 0.09];  % Traverse amplitude, m

% DAQ setup
daq_obj = Config.initialize('TargetPosition', 'MeasuredPosition');

% Create folder for record-keeping
data_folder = fullfile('Data', string(datetime('now', 'Format', 'yyyy_MM_dd')));
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
est_time = seconds(length(CFS) * length(SDS) * length(AS) * ...
    (Config.TOTAL_CYCLES * sum(1 ./ FS) + 2 * Config.OFFSET_DURATION * length(FS)));
est_time.Format = 'hh:mm:ss';
est_elapsed = seconds(0);
est_elapsed.Format = 'hh:mm:ss';

% Create waitbar
h = uifigure('Name', 'Dynamic Testing');
d = uiprogressdlg(h, 'Title', 'Dynamic Testing', 'Cancelable', 'on', 'CancelText', '️️️️⏸');

tic

% Acquire data
for CF = CFS
    for SD = SDS
        for F = FS
            for A = AS
                case_name = sprintf('CF%g_SD%g_F%g_A%g', CF, SD * 100, F, A * 100);
                disp(['Running <strong>' strrep(case_name, '_', ' ') '</strong>.']);

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
                shift = ground + A + SD;
                position = Process.gradual_move(daq_obj, position, shift);
                pause(1);

                % Gather data
                [time, voltages, tare_start, tare_end, ~, ~, pos_encoder, cf_current] = ...
                    dynamic_operation(CF, shift, F, A, daq_obj, lpi, Config.Position);

                % Save data
                filename = fullfile(data_folder, [case_name '.mat']);
                save(filename, 'time', 'voltages', 'tare_start', 'tare_end', 'pos_encoder', 'cf_current');
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

actual_elapsed = seconds(toc);
actual_elapsed.Format = 'hh:mm:ss';
message = sprintf('Estimated time: %s / %s\nElapsed time: %s', est_elapsed, est_time, actual_elapsed);
d.Value = 1;
d.Message = message;
position = Process.gradual_move(daq_obj, position, 0);

pause(3);
close(h);