% -----------------------------------------------------------------------
% Error Analysis Code for Dynamic Quadrotor Experiments
% -----------------------------------------------------------------------

clear; clc; close all hidden;

SRATE = 20000;

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

    data.MeasuredAmplitude(i) = range(motor_position) / 2;

    integral_product = trapz(time, position .* motor_position);
    magnitude_target = trapz(time, position .^ 2);
    magnitude_measured = trapz(time, motor_position .^ 2);
    cos_phi = integral_product / sqrt(magnitude_target * magnitude_measured);
    data.MeasuredPhase(i) = acos(cos_phi);
end

disp('All files processed');
close(fig);

data = sortrows(data, ["TargetAmplitude", "TargetFrequency"]);
writetable(data, fullfile(folder, 'results_manual.csv'));

% Create Bode plots
AS = unique(data.TargetAmplitude);
t = tiledlayout(length(AS), 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Linear Traverse Error Versus Frequency');

for A = AS'
    selection = data(data.TargetAmplitude == A, :);

    nexttile
    p_title = sprintf("Phase Lag Versus Input Frequency (A = %g cm)", A * 100);
    formatplot(p_title, "Input Frequency (Hz)", "Phase Lag (rad)");
    plot(selection.TargetFrequency, abs(selection.TargetPhase - selection.MeasuredPhase), ".-");

    nexttile
    p_title = sprintf("Amplitude Difference Versus Input Frequency (A = %g cm)", A * 100);
    formatplot(p_title, "Input Frequency (Hz)", "Amplitude Difference (cm)");
    plot(selection.TargetFrequency, 100 * abs(selection.TargetAmplitude - selection.MeasuredAmplitude), ".-");
end

function formatplot(p_title, p_x, p_y)
    title(p_title);
    xlabel(p_x);
    ylabel(p_y);
    hold on
    grid on
end