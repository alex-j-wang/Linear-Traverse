% -----------------------------------------------------------------------
% Error Analysis Code for Dynamic Quadrotor Experiments
% -----------------------------------------------------------------------

clear; clc; close all hidden;

folder = "Position Data";
items = dir(fullfile(folder, "*.mat"));
filenames = sort({items.name});

pattern = "F%f_A%f.mat";

% Create progess bar
fig = uifigure('Name', 'Position Comparison');
d = uiprogressdlg(fig, 'Title', 'Position Comparison');

% Data table
columns = {'IntendedAmplitude', 'TargetAmplitude', 'MeasuredAmplitude', ...
    'IntendedFrequency', 'TargetFrequency', 'MeasuredFrequency', ...
    'IntendedPhase', 'TargetPhase', 'MeasuredPhase'
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
    
    data.IntendedAmplitude(i) = A;
    data.TargetAmplitude(i) = target.A;
    data.MeasuredAmplitude(i) = measured.A;

    data.IntendedFrequency(i) = F;
    data.TargetFrequency(i) = target.B;
    data.MeasuredFrequency(i) = measured.B;

    data.IntendedPhase(i) = 0;
    data.TargetPhase(i) = target.C;
    data.MeasuredPhase(i) = measured.C;

    % Plot an example as confirmation
    if (A == 0.025 && F == 0.1) || (A == 0.075 && F == 2.8)
        figure;
        t = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
        title(t, sprintf('Example Plots (A = %g cm, F = %g Hz)', A * 100, F));

        nexttile;
        formatplot('Example Target Signal Fit', 'Time (s)', 'Position (cm)');
        plot(time, 100 * pos_target);
        plot(time, 100 * target(time));
        legend('Target', 'Fit');

        nexttile;
        formatplot('Example Measured Signal Fit', 'Time (s)', 'Position (cm)');
        plot(time, 100 * pos_measured);
        plot(time, 100 * measured(time));
        legend('Measured', 'Fit');

        nexttile;
        formatplot('Example Wave Comparison', 'Time (s)', 'Position (cm)');
        plot(time, 100 * A * sin(2 * pi * F * time));
        plot(time, 100 * target(time));
        plot(time, 100 * measured(time));
        legend('Intended', 'Target', 'Measured');
    end
end

disp('All files processed');
close(fig);

data = sortrows(data, ["IntendedAmplitude", "IntendedFrequency"]);
writetable(data, fullfile(folder, 'results.csv'));

% Create Bode plots
AS = unique(data.IntendedAmplitude);
figure;
t = tiledlayout(2, length(AS), 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Linear Traverse Error Versus Frequency');

for i = 1 : length(AS)
    A = AS(i);
    selection = data(data.IntendedAmplitude == A, :);

    nexttile(t, i);
    p_title = sprintf("Phase Lag Versus Input Frequency (A = %g cm)", A * 100);
    formatplot(p_title, "Input Frequency (Hz)", "Phase Lag (rad)");
    % ylim([0 0.25]);
    plot(selection.IntendedFrequency, abs(selection.TargetPhase - selection.MeasuredPhase), ".-");

    nexttile(t, length(AS) + i);
    p_title = sprintf("Amplitude Ratio Versus Input Frequency (A = %g cm)", A * 100);
    formatplot(p_title, "Input Frequency (Hz)", "Amplitude Ratio (Measured / Intended)");
    ylim([0.8 1.1]);
    plot(selection.IntendedFrequency, selection.MeasuredAmplitude ./ selection.TargetAmplitude, ".-");
end

function fitresult = fit_sinusoid(x, y, A, F)
    % Convert to column vectors
    x = x(:);
    y = y(:);
    
    % Define the sinusoidal fit type
    ft = fittype('A*sin(2*pi*B*x + C) + D', 'independent', 'x', 'coefficients', {'A', 'B', 'C', 'D'});

    % Fit the model to the data
    fitresult = fit(x, y, ft, 'StartPoint', [A, F, 0, 0]);
end