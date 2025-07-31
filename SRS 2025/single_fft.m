% -------------------------------------------------------------------------
% Script for finding mean and standard deviation of static test data
% -------------------------------------------------------------------------

clear; clc; close all hidden;

% Load the calibration matrix for the force transducer
load(['cal_' Config.SENSOR '.mat']);

% Choose static data folder
folder = uigetdir();
[~, foldername, ~] = fileparts(folder);
items = dir(folder);
folders = {items([items.isdir]).name};
folders = folders(3:end);

% Assume all folders contain the same number of files
items = dir(fullfile(folder, folders{1}, '*.mat'));
filenames = {items.name};
SDS = sort(cellfun(@(x) str2double(regexp(x, '(?<=SD)[\d\.]+', 'match')), filenames)) / 100;
dummy = array2table(zeros(length(SDS), length(folders) + 1), 'VariableNames', ["SD" string(folders)]);
dummy.SD = SDS';
results = repmat(table(dummy), 1, 8);
results.Properties.VariableNames = [Config.NAMES "Current" "Transducer RPS"];

% Current analysis parameters
cmin = 1e-3;
cmax = 5;

% Frequency analysis parameters
window = hamming(10000);
nfft = 4 * Config.SRATE;
overlap = 5000;
fmin = 200;
fmax = 350;

num_trials = length(folders);
num_sd = length(SDS);

for t = 2
    trial = folders{t};
    items = dir(fullfile(folder, trial, '*.mat'));
    filenames = sort({items.name});
    for i = 5
        filename = filenames{i};
        load(fullfile(folder, trial, filename), 'voltages', 'cf_current', 'audio') % Includes tare
        forces = (cal_mat * voltages')'; % Conversion to forces and moments

        % Frequency analysis
        [P_force, f_force] = pwelch(forces(:, 3), window, overlap, nfft, Config.SRATE);
        force_mask = f_force >= fmin & f_force <= fmax;
        f_force_trim = f_force(force_mask);
        P_force_trim = P_force(force_mask);

        [~, loc] = max(P_force_trim);
        transducer_rps = f_force_trim(loc);

        % Process.format_plot('', 'Frequency (Hz)', 'Power Spectral Density (dB)')
        plot(f_force_trim, 10 * log10(P_force_trim), 'LineWidth', 1.5);
        xline(transducer_rps, '--', 'LineWidth', 1.5);
        xlim([fmin fmax]);
    end
end

xlabel('Frequency (Hz)', "Interpreter", "latex");
ylabel('Power Spectral Density (dB)', "Interpreter", "latex");
set(gca, 'FontSize', 12, 'FontName', 'Domine');
set(gcf, 'Position', [0 0 335 335]);
exportgraphics(gca, "/Users/alexwang/Downloads/psd.svg", 'ContentType', 'vector');