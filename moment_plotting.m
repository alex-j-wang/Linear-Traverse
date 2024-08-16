clear; clc; close all hidden;

CF = 54.275;
FS = [0.2 0.5 1 1.5 2];
AS = [0 0.025 0.05 0.07];
SDS = [0.005 0.01 0.02 0.03 0.05 0.07];
data_folder = 'Data/drone-drone-moment/processed_data';

screen_size = get(0, 'ScreenSize');
fig = figure('Name', sprintf('Moment Analysis (CF = %g)', CF), ...
    'Position', [0 0 screen_size(3) screen_size(4)]);
t = tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

for F = FS
    nexttile;
    p_title = sprintf('Near-Point M_x Versus Stopping Distance (F = %g Hz)', F);
    Process.format_plot(p_title, 'Stopping Distance (cm)', 'Normalized M_x');
    for A = AS
        throttles = zeros(1, length(SDS));
        errors = zeros(1, length(SDS));
        idx = 1;
        for SD = SDS
            if A == 0
                case_name = sprintf('CF%g_SD%g_F%g_A%g', CF, SD * 100, 1, 0);
                filename = fullfile(data_folder, [case_name '.mat']);
                load(filename, 'forces');
                throttles(idx) = mean(forces.Total(:, 4));
                errors(idx) = std(forces.Total(:, 4));
            else
                case_name = sprintf('CF%g_SD%g_F%g_A%g', CF, SD * 100, F, A * 100);
                filename = fullfile(data_folder, [case_name '.mat']);
                load(filename, 'forces', 'stdev');
                [throttles(idx), I] = min(forces.Total(round(end/2) : round(end * 7/8), 4));
                errors(idx) = stdev(round(end/2) - 1 + I, 4);
            end
            idx = idx + 1;
        end
        if A == 0
            errorbar(SDS * 100, throttles / Config.W / Config.L, errors / Config.W / Config.L, ...
                'x', 'DisplayName', 'Static', 'MarkerSize', 8, 'LineWidth', 1.5);
        else
            errorbar(SDS * 100, throttles / Config.W / Config.L, errors / Config.W / Config.L, ...
                '.', 'DisplayName', sprintf('A = %g cm', A * 100), 'MarkerSize', 20, 'LineWidth', 1.5);
        end
    end
    ylim([-0.27 -0.15]);
    legend();
end