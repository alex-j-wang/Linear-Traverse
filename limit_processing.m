% -----------------------------------------------------------------------
% Data Analysis Code for Dynamic Quadrotor Experiments
% -----------------------------------------------------------------------

clear; clc; close all hidden;

SRATE = 20000; % Sampling frequency
FC = 20; % Cut-off frequency

folder = "Limit Analysis";
items = dir(fullfile(folder, "*.mat"));
filenames = sort({items.name});

pattern = "F%f_A%f.mat";

% Create a uifigure
fig = uifigure('Name', 'Dynamic Processing');

% Create the uiprogressdlg
d = uiprogressdlg(fig, 'Title', 'Processing', 'Message', 'Initializing...', 'Indeterminate', 'on');

pause(1); % Simulate some initialization time

d.Indeterminate = 'off';

% Define the column names
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
end

disp('All files processed');
close(fig);

data = sortrows(data, ["IntendedAmplitude", "IntendedFrequency"]);
writetable(data, fullfile(folder, 'results.csv'));

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

function fitresult = fit_sinusoid(x, y, A0, B0)
    % Ensure that x and y are column vectors
    x = x(:);
    y = y(:);
    
    % Define the sinusoidal fit type
    ft = fittype('A*sin(2*pi*B*x + C) + D', 'independent', 'x', 'coefficients', {'A', 'B', 'C', 'D'});
    
    % Initial guesses for the coefficients
    C0 = 0; % Phase estimate
    D0 = mean(y); % Vertical shift estimate
    
    % Fit the model to the data
    fitresult = fit(x, y, ft, 'StartPoint', [A0, B0, C0, D0]);
end

function formatplot(p_title, p_x, p_y)
    title(p_title);
    xlabel(p_x);
    ylabel(p_y);
    hold on
    grid on
end