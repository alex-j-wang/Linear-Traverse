% Raw position data
clear; clc; close all hidden
figure("Position", [0 0 850 100])
plot(0:1/20000:24-1/20000, 100 * generate_profile(2, 0.08));
xlim([0 24]);
ylim([-10 10]);
axis off
saveas(gcf, '/Users/alexwang/Downloads/position.svg')



% Raw force data
figure("Position", [0 0 850 120])

l1 = patch([time; nan], [forces(:, 1); nan], 'r');
l2 = patch([time; nan], [forces(:, 2); nan], 'r');
l3 = patch([time; nan], [forces(:, 3); nan], 'r');
l4 = patch([time; nan], [forces(:, 4); nan], 'r');
l5 = patch([time; nan], [forces(:, 5); nan], 'r');
l6 = patch([time; nan], [forces(:, 6); nan], 'r');

set(l1, 'EdgeColor', "#0072BD", 'EdgeAlpha', 0.02);
set(l2, 'EdgeColor', "#D95319", 'EdgeAlpha', 0.02);
set(l3, 'EdgeColor', "#EDB120", 'EdgeAlpha', 0.02);
set(l4, 'EdgeColor', "#7E2F8E", 'EdgeAlpha', 0.02);
set(l5, 'EdgeColor', "#77AC30", 'EdgeAlpha', 0.02);
set(l6, 'EdgeColor', "#4DBEEE", 'EdgeAlpha', 0.02);

axis off



% Filtered force data
FC = 20
[b, a] = butter(6, FC / (Config.SRATE / 2));
filtered = zeros(size(forces));
for col = 1:6
        filtered(:, col) = -filtfilt(b, a, forces(:, col));
end
figure("Position", [0 0 850 135])
plot(filtered)
ylim([-0.85 1.6])
axis off

legend(Config.NAMES, 'Orientation','horizontal', 'Location', 'southoutside', 'FontWeight', 'bold', 'box', 'off', 'TextColor', [0.5 0.5 0.5], 'FontName', 'Domine')



% Phase averaged force & moment data
figure
hold on
yyaxis left
plot(time, total_force(:, 1), 'Color', "#0072BD", 'LineStyle', '-', 'LineWidth', 1.5)
plot(time, total_force(:, 2), 'Color', "#D95319", 'LineStyle', '-', 'LineWidth', 1.5)
plot(time, total_force(:, 3), 'Color', "#EDB120", 'LineStyle', '-', 'LineWidth', 1.5)
ylabel('Force (N)', 'FontName', 'Domine')
yyaxis right
plot(time, total_force(:, 4), 'Color', "#7E2F8E", 'LineStyle', '-', 'LineWidth', 1.5)
plot(time, total_force(:, 5), 'Color', "#77AC30", 'LineStyle', '-', 'LineWidth', 1.5)
plot(time, total_force(:, 6), 'Color', "#4DBEEE", 'LineStyle', '-', 'LineWidth', 1.5)
ylabel('Moment (Nmm)', 'FontName', 'Domine')
legend(Config.NAMES, 'FontName', 'Domine')
xlabel('Time (s)', 'FontName', 'Domine')
title('Forces & Moments Versus Time', 'FontName', 'Domine')
grid on



% Phase averaged F_z forces and position
figure
hold on
yyaxis left
plot(time, forces.Total(:, 3) / Config.W, 'Color', "#0072BD", 'LineStyle', '-', 'LineWidth', 1.5, 'DisplayName', 'Total')
plot(time, forces.Intertial(:, 3) / Config.W, 'Color', "#D95319", 'LineStyle', '-', 'LineWidth', 1.5, 'DisplayName', 'Inertial')
plot(time, forces.Lift(:, 3) / Config.W, 'Color', "#EDB120", 'LineStyle', '-', 'LineWidth', 1.5, 'DisplayName', 'Lift')
ylabel('Normalized Force', 'FontName', 'Domine')
yyaxis right
plot(time, pos_encoder * 100, 'Color', "#7E2F8E", 'LineStyle', '--', 'LineWidth', 1.5, 'DisplayName', 'Position')
ylabel('Position (cm)', 'FontName', 'Domine')
legend('FontName', 'Domine')
xlabel('Time (s)', 'FontName', 'Domine')
title('F_z & Position Versus Time', 'FontName', 'Domine')
ax = gca;
ax.YAxis(2).Color = "#7E2F8E";
grid on