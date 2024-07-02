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
d = uiprogressdlg(fig, 'Title', 'Processing', 'Message', 'Initializing...', 'Indeterminate', 'on');
pause(1);
d.Indeterminate = 'off';

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
    target = fit_sinusoid(time, position, A, F);
    measured = fit_sinusoid(time, motor_position, A, F);
    
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
    if i == 1
        figure
        p_title = sprintf('Example Sinusoid Fit (A = %g cm, F = %g Hz)', A * 100, F);
        formatplot(p_title, 'Time (s)', 'Position (cm)');
        plot(time, 100 * motor_position);
        plot(time, 100 * measured(time));
        legend('Measured', 'Fit');

        figure
        p_title = sprintf('Example Wave Comparison (A = %g cm, F = %g Hz)', A * 100, F);
        formatplot(p_title, 'Time (s)', 'Position (cm)');
        plot(time, 100 * target(time));
        plot(time, 100 * measured(time));
        legend('Target', 'Measured');
    end
end

disp('All files processed');
close(fig);

data = sortrows(data, ["IntendedAmplitude", "IntendedFrequency"]);
writetable(data, fullfile(folder, 'results.csv'));

% Create Bode plots
AS = unique(data.IntendedAmplitude);
t = tiledlayout(length(AS), 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Linear Traverse Error Versus Frequency');

for A = AS'
    selection = data(data.IntendedAmplitude == A, :);

    nexttile
    p_title = sprintf("Phase Lag Versus Input Frequency (A = %g cm)", A * 100);
    formatplot(p_title, "Input Frequency (Hz)", "Phase Lag (rad)");
    plot(selection.IntendedFrequency, abs(selection.IntendedPhase - selection.MeasuredPhase), ".-");

    nexttile
    p_title = sprintf("Amplitude Difference Versus Input Frequency (A = %g cm)", A * 100);
    formatplot(p_title, "Input Frequency (Hz)", "Amplitude Difference (cm)");
    plot(selection.IntendedFrequency, 100 * abs(selection.IntendedAmplitude - selection.MeasuredAmplitude), ".-");
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