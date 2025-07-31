% -------------------------------------------------------------------------
% Script for finding mean and standard deviation of static test data
% -------------------------------------------------------------------------

clear; clc; close all hidden;

% Load the calibration matrix for the force transducer
load(['cal_' Config.SENSOR '.mat']);

% Choose static data folder
items = dir('Data');
dir_names = {items([items.isdir]).name};
matching_folders = dir_names(~ismember(dir_names, {'.', '..'}));

folder = interface.dropdown(matching_folders, 'Select a folder');
items = dir(fullfile('Data', folder));
folders = {items([items.isdir]).name};
folders = folders(3:end);

% Assume all folders contain the same number of files
items = dir(fullfile('Data', folder, folders{1}, '*.mat'));
filenames = {items.name};
SDS = sort(cellfun(@(x) str2double(regexp(x, '(?<=SD)[\d\.]+', 'match')), filenames)) / 100;
dummy = array2table(zeros(length(SDS), length(folders) + 1), 'VariableNames', ["SD" string(folders)]);
dummy.SD = SDS';
results = repmat(table(dummy), 1, 9);
results.Properties.VariableNames = [Config.NAMES "Current" "Transducer RPS" "Traverse RPS"];

% Create progress bar
fig = uifigure('Name', 'Static Processing');
d = uiprogressdlg(fig, 'Title', sprintf('Processing (%s)', folder));
disp(['Processing <strong>' folder '</strong>.']);

% Frequency analysis parameters
window = hamming(10000);
nfft = Config.SRATE * 2;
overlap = 5000;
fmin = 200;
fmax = 350;

for t = 1 : length(folders)
    trial = folders{t};
    items = dir(fullfile('Data', folder, trial, '*.mat'));
    filenames = sort({items.name});
    for i = 1 : length(filenames)
        filename = filenames{i};
        d.Value = ((t - 1) * length(filenames) + (i - 1)) / length(folders) / length(filenames);
        d.Message = [folders{t} ' ' strrep(filename, '_', ' ')];

        load(fullfile('Data', folder, trial, filename), 'voltages', 'cf_current', 'audio') % Includes tare
        forces = (cal_mat * voltages')'; % Conversion to forces and moments

        % Extract and convert parameters
        parameters = num2cell(sscanf(filename, 'CF%f_SD%f_F%f_A%f.mat'));
        [~, SD, ~, ~] = deal(parameters{:});
        idx = find(SDS == SD / 100);

        % Store average forces
        for a = 1 : length(Config.NAMES)
            results.(Config.NAMES(a)).(trial)(idx) = mean(forces(:, a));
        end

        % Mean current
        results.Current.(trial)(idx) = mean(cf_current);

        % Frequency analysis
        [P_audio, f_audio] = pwelch(audio, window, overlap, nfft, Config.SRATE);
        [P_force, f_force] = pwelch(forces(:, 3), window, overlap, nfft, Config.SRATE);

        audio_mask = f_audio >= fmin & f_audio <= fmax;
        force_mask = f_force >= fmin & f_force <= fmax;
        f_audio_trim = f_audio(audio_mask);
        P_audio_trim = P_audio(audio_mask);
        f_force_trim = f_force(force_mask);
        P_force_trim = P_force(force_mask);

        % Find peaks
        [pks_audio, locs_audio] = findpeaks(P_audio_trim, f_audio_trim);
        [pks_force, locs_force] = findpeaks(P_force_trim, f_force_trim);

        locs = locs_audio;
        pks = pks_audio .* interp1(locs_force, pks_force, locs, 'nearest', 'extrap');
        [~, top_idx] = maxk(pks, 2);
        top_locs = locs(top_idx);
        transducer_rps = max(top_locs);
        traverse_rps = min(top_locs);

        results.("Transducer RPS").(trial)(idx) = transducer_rps;
        results.("Traverse RPS").(trial)(idx) = traverse_rps;

        % Optional debug plot
        figure;
        axis('square');
        hold on;
        plot(f_audio_trim, 10 * log10(P_audio_trim), 'b', 'LineWidth', 1);
        plot(f_force_trim, 10 * log10(P_force_trim), 'r', 'LineWidth', 1);
        scatter(locs_audio, 10 * log10(pks_audio), 'bo', 'filled');
        scatter(locs_force, 10 * log10(pks_force), 'ro', 'filled');
        xline(transducer_rps, 'g--', 'LineWidth', 1.5);
        xline(traverse_rps, 'm--', 'LineWidth', 1.5);
        title(strrep(filename, '_', '\_'));
        xlabel('Frequency (Hz)');
        ylabel('Amplitude (dB)')
        legend(["Audio" "Force"]);
    end
end

% save(fullfile('Data', folder, 'processed_data.mat'), 'results', '-mat');

d.Value = 1;
d.Message = 'All files processed';
pause(1);

close(fig);
