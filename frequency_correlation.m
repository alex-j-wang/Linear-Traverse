% -------------------------------------------------------------------------
% Script for comparing audio and force frequency data (plot & table)
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

dummy = array2table(zeros(length(index), length(folders) + 2), ...
    'VariableNames', ["SD" "TP" string(folders)]);
dummy.SD = index(:, 1) / 100;
dummy.TP = index(:, 2);

names = ["Lower Force" "Upper Force" "Audio"];
results = repmat(table(dummy), 1, numel(names));
results.Properties.VariableNames = names;

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
force_fmin = 100;
force_fmax = 500;
audio_fmin = 660;
audio_fmax = 740;

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

        % Lower
        [P_force, f_force] = pwelch(lower_forces(:, 3), window, overlap, nfft, Config.SRATE);
        force_mask = f_force >= force_fmin & f_force <= force_fmax;
        f_force_trim = f_force(force_mask);
        P_force_trim = P_force(force_mask);

        [~, loc] = max(P_force_trim);
        rps = f_force_trim(loc);
        results.("Lower Force").(trial)(idx) = 2 * rps;

        % Upper
        [P_force, f_force] = pwelch(upper_forces(:, 3), window, overlap, nfft, Config.SRATE);
        force_mask = f_force >= force_fmin & f_force <= force_fmax;
        f_force_trim = f_force(force_mask);
        P_force_trim = P_force(force_mask);

        [~, loc] = max(P_force_trim);
        rps = f_force_trim(loc);
        results.("Upper Force").(trial)(idx) = 2 * rps;

        % Audio
        audio = data{:, "Microphone"};
        [P_audio, f_audio] = pwelch(audio, window, overlap, nfft, Config.SRATE);
        audio_mask = f_audio >= audio_fmin & f_audio <= audio_fmax;
        f_audio_trim = f_audio(audio_mask);
        P_audio_trim = P_audio(audio_mask);

        % Blade passage frequency
        [~, loc] = max(P_audio_trim);
        bpf = f_audio_trim(loc);
        results.("Audio").(trial)(idx) = bpf;
    end
end

d.Value = 1;
d.Message = 'All files processed';
pause(1);

close(fig);

save(fullfile(folder, "frequency_comparison.mat"), "results");
force_lower = median(results.("Lower Force"){:, ["T01" "T02" "T03"]}, 2);
force_upper = median(results.("Upper Force"){:, ["T01" "T02" "T03"]}, 2);
audio = median(results.Audio{:, ["T01" "T02" "T03"]}, 2);

title = sprintf("Frequency Comparison ($\\Psi = %d^\\circ$)", yaw);
Process.format_plot(title, "Separation, $\Delta z/l$", "Peak Frequency (Hz)");
hold on;

SDS = results.Audio.SD / (Config.L / 1000);
plot(SDS, force_lower, 'g.-', 'DisplayName', 'Lower Force', 'LineWidth', 1.5, 'MarkerSize', 15);
plot(SDS, force_upper, 'r.-', 'DisplayName', 'Upper Force', 'LineWidth', 1.5, 'MarkerSize', 15);
plot(SDS, audio, 'b.-', 'DisplayName', 'Audio', 'LineWidth', 1.5, 'MarkerSize', 15);
legend('Location', 'best');

set(gcf, 'Renderer', 'painters');
print(gcf, fullfile(folder, "frequency_comparison.svg"), "-dsvg");
