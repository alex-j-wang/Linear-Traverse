% -----------------------------------------------------------------------
% Error Analysis Code for Dynamic Quadrotor Experiments
% -----------------------------------------------------------------------

clear; clc; close all hidden;

folder = "Limit Analysis";
items = dir(fullfile(folder, "*.mat"));
filenames = sort({items.name});

pattern = "F%f_A%f.mat";

% Create progess bar
fig = uifigure('Name', 'Dynamic Processing');
d = uiprogressdlg(fig, 'Title', 'Processing');

% Data table
columns = {'TargetAmplitude', 'MeasuredAmplitude', ...
    'TargetFrequency', 'MeasuredFrequency', ...
    'TargetPhase', 'MeasuredPhase'
};
data = array2table(NaN(length(filenames), length(columns)), 'VariableNames', columns);

for i = 1 : length(filenames)
    filename = filenames{i};
    d.Value = (i - 1) / length(filenames);
    d.Message = strrep(filename, '_', ' ');

    parameters = num2cell(sscanf(filename, pattern));
    [F, A] = deal(parameters{:});
    A = A / 100;

    load(fullfile(folder, filename));
    
    data.TargetAmplitude(i) = A;
    data.TargetFrequency(i) = F;
    data.TargetPhase(i) = 0;

    data.MeasuredAmplitude(i) = range(pos_measured) / 2;

    pos_measured = pos_measured - mean(pos_measured);
    integral_product = trapz(time, pos_target .* pos_measured);
    magnitude_target = trapz(time, pos_target .^ 2);
    magnitude_measured = trapz(time, pos_measured .^ 2);
    cos_phi = integral_product / sqrt(magnitude_target * magnitude_measured);
    data.MeasuredPhase(i) = acos(cos_phi);
end

disp('All files processed');
close(fig);

data = sortrows(data, ["TargetAmplitude", "TargetFrequency"]);
writetable(data, fullfile(folder, 'results_manual.csv'));

% Create Bode plots
AS = unique(data.TargetAmplitude);
t = tiledlayout(2, length(AS), 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Linear Traverse Error Versus Frequency');

for i = 1 : length(AS)
    A = AS(i);
    selection = data(data.TargetAmplitude == A, :);

    nexttile(t, i);
    p_title = sprintf("Phase Lag Versus Input Frequency (A = %g cm)", A * 100);
    formatplot(p_title, "Input Frequency (Hz)", "Phase Lag (rad)");
    xlim([0.5 4]);
    ylim([0 0.25]);
    plot(selection.TargetFrequency, abs(selection.TargetPhase - selection.MeasuredPhase), ".-");

    nexttile(t, length(AS) + i);
    p_title = sprintf("Amplitude Difference Versus Input Frequency (A = %g cm)", A * 100);
    formatplot(p_title, "Input Frequency (Hz)", "Amplitude Difference (cm)");
    xlim([0.5 4]);
    ylim([0 1.25]);
    plot(selection.TargetFrequency, 100 * abs(selection.TargetAmplitude - selection.MeasuredAmplitude), ".-");
end