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

d.Value = 1;
d.Message = 'All files processed';
disp('All files processed');
data = sortrows(data, ["IntendedFrequency", "IntendedAmplitude"]);
writetable(data, fullfile(folder, 'results.csv'));

pause(1);

close(fig);

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