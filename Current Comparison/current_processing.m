% ----------------------------------------------------------
% Script saving statistics and plotting current data
% ----------------------------------------------------------

clear; clc; close all hidden;

folder = "Current Data";
items = dir(fullfile(folder, "*.mat"));
filenames = sort({items.name});

pattern = "F%f_A%f.mat";

% Create progess bar
fig = uifigure('Name', 'Current Comparison');
d = uiprogressdlg(fig, 'Title', 'Current Comparison');

% Data table
columns = {'IntendedAmplitude', 'IntendedFrequency', 'DemandedCurrent', 'MeasuredCurrent', 'RMSE'};
data = array2table(NaN(length(filenames), length(columns)), 'VariableNames', columns);

figure;
t = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Example Current Plots');

for i = 1 : length(filenames)
    filename = filenames{i};
    d.Value = (i - 1) / length(filenames);
    d.Message = strrep(filename, '_', ' ');

    parameters = num2cell(sscanf(filename, pattern));
    [F, A] = deal(parameters{:});
    A = A / 100;

    load(fullfile(folder, filename));
    
    data.IntendedAmplitude(i) = A;
    data.IntendedFrequency(i) = F;
    data.DemandedCurrent(i) = mean(curr_target);
    data.MeasuredCurrent(i) = mean(curr_measured);
    data.RMSE(i) = rmse(curr_target, curr_measured);

    % Plot examples
    if F == 0.1 || F == 2.8
        nexttile;
        p_title = sprintf("Current Plots (A = %g cm, F = %g Hz)", A * 100, F);
        formatplot(p_title, "Time (s)", "Current (A)");
        % xlim([0, 5 / F]);
        selection = round(linspace(1, length(curr_target), 1000));
        
        l1 = patch([time(selection); nan], [curr_target(selection); nan], 'r');
        l2 = patch([time(selection); nan], [curr_measured(selection); nan], 'b');
        set(l1, 'EdgeColor', 'r', 'EdgeAlpha', 0.2);
        set(l2, 'EdgeColor', 'b', 'EdgeAlpha', 0.2);
        legend("Demanded", "Measured");
    end
end

disp('All files processed');
close(fig);

data = sortrows(data, ["IntendedAmplitude", "IntendedFrequency"]);
writetable(data, fullfile(folder, 'results.csv'));