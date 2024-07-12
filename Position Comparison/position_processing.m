% ----------------------------------------------------------
% Script generating sinusoidal fits for data comparison
% ----------------------------------------------------------

clear; clc; close all hidden;

screen_size = get(0, 'ScreenSize');
fig_position = [0, screen_size(4) - 400, screen_size(3), 400];

folder = "Position Data";
items = dir(fullfile(folder, "*.mat"));
filenames = sort({items.name});

pattern = "F%f_A%f.mat";

% Create progess bar
fig = uifigure('Name', 'Position Comparison');
d = uiprogressdlg(fig, 'Title', 'Position Comparison');

% Data table
columns = {'IntendedAmplitude', 'EncoderAmplitude', 'TargetAmplitude', 'MeasuredAmplitude', ...
    'IntendedFrequency', 'EncoderFrequency', 'TargetFrequency', 'MeasuredFrequency', ...
    'IntendedPhase', 'EncoderPhase', 'TargetPhase', 'MeasuredPhase'
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
    
    % Fit sinusoids and record results
    target = fit_sinusoid(time, pos_target, A, F);
    measured = fit_sinusoid(time, pos_measured, A, F);
    encoder = fit_sinusoid(time, pos_encoder, A, F);
    
    data.IntendedAmplitude(i) = A;
    data.EncoderAmplitude(i) = encoder.A;
    data.TargetAmplitude(i) = target.A;
    data.MeasuredAmplitude(i) = measured.A;

    data.IntendedFrequency(i) = F;
    data.EncoderFrequency(i) = encoder.B;
    data.TargetFrequency(i) = target.B;
    data.MeasuredFrequency(i) = measured.B;

    data.IntendedPhase(i) = 0;
    data.EncoderPhase(i) = encoder.C;
    data.TargetPhase(i) = target.C;
    data.MeasuredPhase(i) = measured.C;

    % Plot an example as confirmation
    if (A == 0.025 && F == 0.1) || (A == 0.075 && F == 2.8)
        figure('Position', fig_position);
        t = tiledlayout(1, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
        title(t, sprintf('Example Plots (A = %g cm, F = %g Hz)', A * 100, F));

        nexttile;
        format_plot('Example Encoder Signal Fit', 'Time (s)', 'Position (cm)');
        plot(time, 100 * pos_encoder);
        plot(time, 100 * encoder(time));
        % xlim([0, 5 / F]);
        ylim([-100 * A - 1, 100 * A + 1]);
        legend('Encoder', 'Fit');

        nexttile;
        format_plot('Example Target Signal Fit', 'Time (s)', 'Position (cm)');
        plot(time, 100 * pos_target);
        plot(time, 100 * target(time));
        % xlim([0, 5 / F]);
        ylim([-100 * A - 1, 100 * A + 1]);
        legend('Target', 'Fit');

        nexttile;
        format_plot('Example Measured Signal Fit', 'Time (s)', 'Position (cm)');
        plot(time, 100 * pos_measured);
        plot(time, 100 * measured(time));
        % xlim([0, 5 / F]);
        ylim([-100 * A - 1, 100 * A + 1]);
        legend('Measured', 'Fit');

        nexttile;
        format_plot('Example Wave Comparison', 'Time (s)', 'Position (cm)');
        plot(time, 100 * A * sin(2 * pi * F * time));
        plot(time, 100 * encoder(time));
        plot(time, 100 * target(time));
        plot(time, 100 * measured(time));
        % xlim([0, 5 / F]);
        ylim([-100 * A - 1, 100 * A + 1]);
        legend('Intended', 'Encoder', 'Target', 'Measured');
    end
end

disp('All files processed');
close(fig);

data = sortrows(data, ["IntendedAmplitude", "IntendedFrequency"]);
writetable(data, fullfile(folder, 'results.csv'));

% Create Bode plots
AS = unique(data.IntendedAmplitude);
f1 = figure('Position', screen_size);
t1 = tiledlayout(f1, 2, length(AS), 'TileSpacing', 'compact', 'Padding', 'compact');
title(t1, 'Linear Traverse Error Versus Frequency (Target & Measured)');
f2 = figure('Position', screen_size);
t2 = tiledlayout(f2, 2, length(AS), 'TileSpacing', 'compact', 'Padding', 'compact');
title(t2, 'Linear Traverse Error Versus Frequency (Intended & Encoder)');


for i = 1 : length(AS)
    A = AS(i);
    selection = data(data.IntendedAmplitude == A, :);

    nexttile(t1, i);
    p_title = sprintf("Phase Lag Versus Input Frequency (A = %g cm)", A * 100);
    format_plot(p_title, "Input Frequency (Hz)", "Phase Lag (rad)");
    plot(selection.IntendedFrequency, abs(selection.TargetPhase - selection.MeasuredPhase), ".-");

    nexttile(t1, length(AS) + i);
    p_title = sprintf("Amplitude Ratio Versus Input Frequency (A = %g cm)", A * 100);
    format_plot(p_title, "Input Frequency (Hz)", "Amplitude Ratio (Measured : Target)");
    plot(selection.IntendedFrequency, selection.MeasuredAmplitude ./ selection.TargetAmplitude, ".-");

    nexttile(t2, i);
    p_title = sprintf("Phase Lag Versus Input Frequency (A = %g cm)", A * 100);
    format_plot(p_title, "Input Frequency (Hz)", "Phase Lag (rad)");
    plot(selection.IntendedFrequency, abs(selection.EncoderPhase - selection.IntendedPhase), ".-");

    nexttile(t2, length(AS) + i);
    p_title = sprintf("Amplitude Ratio Versus Input Frequency (A = %g cm)", A * 100);
    format_plot(p_title, "Input Frequency (Hz)", "Amplitude Ratio (Encoder : Intended)");
    plot(selection.IntendedFrequency, selection.EncoderAmplitude ./ selection.IntendedAmplitude, ".-");
end

function fitresult = fit_sinusoid(x, y, A, F)
    % FIT_SINUSOID  Fit a sinusoidal model to the data using A and F as starting conditions
    x = x(:);
    y = y(:);
    ft = fittype('A*sin(2*pi*B*x + C) + D', 'independent', 'x', 'coefficients', {'A', 'B', 'C', 'D'});
    fitresult = fit(x, y, ft, 'StartPoint', [A, F, 0, 0]);
end