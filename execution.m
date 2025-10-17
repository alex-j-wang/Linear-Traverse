% -------------------------------------------------------------------------
% Script to run experiments and save dynamic test data
% -------------------------------------------------------------------------

clear; clc; close all hidden;

% Test parameters
CFS = 1; % Normalized Crazyflie thrust
SDS = [0.035 0.04 0.07 0.10]; % Stopping distance, m
FS = [0.2 0.5 0.75 1];  % Traverse frequency, Hz
AS = [.025 0.05 0.07 0.09];  % Traverse amplitude, m
YAW = 0;
TRAV = 'CF65'; % Disabled during hover normalization

% Load the calibration matrix for the force transducer
load(['cal_' Config.SENSOR '.mat']);

% DAQ setup
daq_obj = Config.initialize();

% Create folder for record-keeping
data_folder = fullfile('Data', [char(datetime('now', 'Format', 'yyyy_MM_dd')) '_DYN']);
if exist(data_folder, 'dir')
    mkdir(data_folder);
end

% Warn about overwriting data
overwritten = [];
for CF = CFS
    for SD = SDS
        for F = FS
            for A = AS
                case_name = sprintf('CF%g_SD%g_F%g_A%g', CF, SD * 100, F, A * 100);
                filename = fullfile(trial_folder, [case_name '.mat']);
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
disp('Calibrating hover throttle.');
hover_throttle = Config.get_hover;
hover_thrust = [];
shift = ground + SDS(end) - Config.H / 1000;
position = Process.gradual_move(daq_obj, position, shift);
while true
    pause(1);
    [~, voltages] = dynamic_operation(hover_throttle(end), shift, 4, 0, daq_obj, lpi, TRAV);
    forces = mean(cal_mat * voltages', 2);
    hover_thrust(end + 1) = forces(3);
    fprintf('T%g -> %g N\n', hover_throttle(end), hover_thrust(end));
    if abs(hover_thrust(end) - Config.W) < Config.HOVER_TOLERANCE
        fprintf('Hover throttle: %g%%\n', hover_throttle(end));
        break;
    else
        hover_throttle(end + 1) = Config.W / hover_thrust(end) * hover_throttle(end);
    end
end
Config.set_hover(hover_throttle(end));

save(fullfile(data_folder, 'calibration.mat'), 'hover_throttle', 'hover_thrust', 'lpi');
loadenv(".env")
url = getenv("SLACK_WEBHOOK_URL");
msg = struct('text', sprintf('Hover throttle identified as %g%%', Config.get_hover));
webwrite(url, msg, weboptions('MediaType','application/json'));

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
                [time, voltages, tare_start, tare_end, motor_voltage, audio, pos_encoder, cf_current] = ...
                    dynamic_operation(CF * Config.get_hover, shift, F, A, daq_obj, lpi);

                % Save data
                filename = fullfile(data_folder, [case_name '.mat']);
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
end

actual_elapsed = seconds(toc(start_time));
actual_elapsed.Format = 'hh:mm:ss';
message = sprintf('Estimated time: %s / %s\nElapsed time: %s', est_elapsed, est_time, actual_elapsed);
d.Value = 1;
d.Message = message;
position = Process.gradual_move(daq_obj, position, 0);

msg = struct('text', ['Dynamic testing for ' data_folder ' completed in ' char(actual_elapsed)]);
webwrite(url, msg, weboptions('MediaType','application/json'));

pause(3);
close(h);
