% -------------------------------------------------------------------------
% Script to calculate phase lag between intended and encoder position
% -------------------------------------------------------------------------

clear; clc; close all hidden;

folder = 'Position Data';
items = dir(fullfile(folder, '*.mat'));
filenames = sort({items.name});

% Create progess bar
fig = uifigure('Name', 'Position Comparison');
d = uiprogressdlg(fig, 'Title', 'Position Comparison');

% Data table
columns = {'IntendedAmplitude', 'EncoderAmplitude', ...
    'IntendedFrequency', 'EncoderFrequency', ...
    'IntendedPhase', 'EncoderPhase'
};
data = array2table(NaN(length(filenames), length(columns)), 'VariableNames', columns);

for i = 1 : length(filenames)
    filename = filenames{i};
    d.Value = (i - 1) / length(filenames);
    d.Message = strrep(filename, '_', ' ');

    parameters = num2cell(sscanf(filename, 'F%f_A%f.mat'));
    [F, A] = deal(parameters{:});
    A = A / 100;

    load(fullfile(folder, filename));
    pos_intended = A * sin(2 * pi * F * time);
    
    data.IntendedAmplitude(i) = A;
    data.IntendedFrequency(i) = F;
    data.IntendedPhase(i) = 0;

    data.EncoderAmplitude(i) = range(pos_encoder) / 2;

    integral_product = trapz(time, pos_intended .* pos_encoder);
    magnitude_intended = trapz(time, pos_intended .^ 2);
    magnitude_encoder = trapz(time, pos_encoder .^ 2);
    cos_phi = integral_product / sqrt(magnitude_intended * magnitude_encoder);
    data.EncoderPhase(i) = acos(cos_phi);
end

disp('All files processed');
close(fig);

data = sortrows(data, ["IntendedAmplitude" "IntendedFrequency"]);
writetable(data, fullfile(folder, 'results_manual.csv'));

% Create plots
AS = unique(data.IntendedAmplitude);
t = tiledlayout(2, length(AS), 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Linear Traverse Error Versus Frequency');

for i = 1 : length(AS)
    A = AS(i);
    selection = data(data.IntendedAmplitude == A, :);

    nexttile(t, i);
    p_title = sprintf('Phase Lag Versus Input Frequency (A = %g cm)', A * 100);
    Process.format_plot(p_title, 'Input Frequency (Hz)', 'Phase Lag (rad)');
    plot(selection.IntendedFrequency, abs(selection.IntendedPhase - selection.EncoderPhase), '.-');

    nexttile(t, length(AS) + i);
    p_title = sprintf('Amplitude Ratio Versus Input Frequency (A = %g cm)', A * 100);
    Process.format_plot(p_title, 'Input Frequency (Hz)', 'Amplitude Ratio (Encoder : Intended)');
    plot(selection.IntendedFrequency, selection.EncoderAmplitude ./ selection.IntendedAmplitude, '.-');
end