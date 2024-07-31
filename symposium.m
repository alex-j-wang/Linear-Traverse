% F1 A2.5

clear; clc; close all hidden;

title("Static and Dynamic Near-Point F_z Versus Stopping Distance", "FontName", "Domine");
xlabel("Normalized Stopping Distance", "FontName", "Domine");
ylabel("Normalized Force", "FontName", "Domine");
hold on
grid on

SDS = [0.5 1 2 3 5] * 10 / Config.L;
dynamic = [1.39993 1.38901 1.334 1.27059 1.14683];

% for SD = [0.5 1 2 3 5]
%     load("CF75_SD" + SD + "_F1_A0.mat")
%     disp(-mean(forces(:, 3)))
% end

static = [0.4587 0.4576 0.4360 0.4174 0.4151] / Config.W;

plot(SDS, static, 'x', 'DisplayName', 'Static', 'MarkerSize', 10, 'LineWidth', 3)
plot(SDS, dynamic, '.', 'DisplayName', 'Dynamic', 'MarkerSize', 20)
% xlim([0 5.5])
% set(gca, 'FontSize', 12)
legend()