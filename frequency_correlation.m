% -------------------------------------------------------------------------
% Script for copmaring audio and force frequency data
% -------------------------------------------------------------------------

clear; clc; close all hidden;

% Load force transducer calibration matrices
lower_cal = load(['cal_' Config.LOWER_FT '.mat'], 'cal_mat').('cal_mat');
upper_cal = load(['cal_' Config.UPPER_FT '.mat'], 'cal_mat').('cal_mat');

% Choose data folder
folder = uigetdir;
[~, foldername] = fileparts(folder);
items = dir(folder);
folders = {items([items.isdir]).name};
folders = folders(3:end);

% Assume all folders contain the same number of files
items = dir(fullfile(folder, folders{1}, '*.mat'));
filenames = {items.name};
tok = regexp(filenames, 'SD([\d\.]+)_TP([\d\.]+)', 'tokens');
tok = cellfun(@(x) x{1}, tok, 'UniformOutput', false);
index = sortrows(str2double(vertcat(tok{:})));
index = index(1:10, :);

dummy = array2table(zeros(length(index), length(folders) + 2), ...
    'VariableNames', ["SD" "TP" string(folders)]);
dummy.SD = index(:, 1) / 100;
dummy.TP = index(:, 2);

lower_names = "Lower " + ["Force" "Audio"];
upper_names = "Upper " + ["Force" "Audio"];
results = repmat(table(dummy), 1, numel(lower_names) + numel(upper_names));
results.Properties.VariableNames = [lower_names upper_names];

% Create progress bar
fig = uifigure('Name', 'Static Processing');
d = uiprogressdlg(fig, 'Title', sprintf('Processing (%s)', foldername));
fprintf("Processing <strong>%s</strong>.\n", foldername);

% Force analysis parameter
yaw = str2double(regexp(foldername, '(?<=Y)[\d\-]+', 'match'));

% Frequency analysis parameters
nfft = Config.SRATE;
window = hamming(nfft);
overlap = nfft / 2;
fmin = 100;
fmax = 500;

num_rows = length(folders);
num_cols = length(index);

for t = 1 : length(folders)
    trial = folders{t};
    items = dir(fullfile(folder, trial, '*.mat'));
    filenames = sort({items.name});
    for i = 1 : length(filenames)
        filename = filenames{i};
        d.Value = ((t - 1) * length(filenames) + (i - 1)) / length(folders) / length(filenames);
        d.Message = [folders{t} ' ' strrep(filename, '_', ' ')];

        load(fullfile(folder, trial, filename), 'data') % Includes tare

        % Extract and convert parameters
        parameters = num2cell(sscanf(filename, 'CF%f_SD%f_TP%f_F%f.mat'));
        [~, SD, TP, ~] = deal(parameters{:});
        idx = find(dummy.SD == SD / 100 & dummy.TP == TP);
        if isempty(idx)
            continue
        end

        voltages = data{:, Config.LOWER_FT_CH};
        lower_forces = (Config.lower_to_world * lower_cal * voltages')';
        voltages = data{:, Config.UPPER_FT_CH};
        upper_forces = (Config.upper_to_world(yaw) * upper_cal * voltages')';

        % Frequency analysis
        subidx = (t - 1) * num_cols + idx;
        subplot(num_rows, num_cols, subidx);
        title("T" + t + " SD" + SD);
        xlim([fmin fmax]);
        hold on;

        % Lower
        [P_force, f_force] = pwelch(lower_forces(:, 3), window, overlap, nfft, Config.SRATE);
        force_mask = f_force >= fmin & f_force <= fmax;
        f_force_trim = f_force(force_mask);
        P_force_trim = P_force(force_mask);

        [~, loc] = max(P_force_trim);
        rps = f_force_trim(loc);
        results.("Lower Force").(trial)(idx) = rps;
        xline(rps, 'g--', 'LineWidth', 1.5, 'Alpha', 0.15);

        % Upper
        [P_force, f_force] = pwelch(upper_forces(:, 3), window, overlap, nfft, Config.SRATE);
        force_mask = f_force >= fmin & f_force <= fmax;
        f_force_trim = f_force(force_mask);
        P_force_trim = P_force(force_mask);

        [~, loc] = max(P_force_trim);
        rps = f_force_trim(loc);
        results.("Upper Force").(trial)(idx) = rps;
        xline(rps, 'r--', 'LineWidth', 1.5, 'Alpha', 0.15);

        % Audio
        audio = data{:, "Microphone"};
        [P_audio, f_audio] = pwelch(audio, window, overlap, nfft, Config.SRATE);
        audio_mask = f_audio >= fmin & f_audio <= fmax;
        f_audio_trim = f_audio(audio_mask);
        P_audio_trim = P_audio(audio_mask);

        plot(f_audio_trim, 10 * log10(P_audio_trim), 'b');
    end
end

set(gcf, 'Renderer', 'painters');
print(gcf, fullfile(folder, "frequency.svg"), "-dsvg");

d.Value = 1;
d.Message = 'All files processed';
pause(1);

close(fig);
