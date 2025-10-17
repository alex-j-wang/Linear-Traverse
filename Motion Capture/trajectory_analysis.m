clear; clc; close all hidden;

load("/Users/alexwang/Downloads/trajectory_data_pid_0.35ms_poskp2.5");
stop = 1650;
idx = 1:stop;
goal = cf74.goal;
actual = cf74.actual;

plot3(goal(idx, 1), goal(idx, 2), goal(idx, 3), 'k--', 'LineWidth', 1.5);
hold on;

lag = vecnorm(goal - actual, 2, 2);
scatter3(actual(idx, 1), actual(idx, 2), actual(idx, 3), 3, lag(idx), 'filled');
colormap jet;
colorbar;

legend('Goal', 'Actual');
xlabel('X'); ylabel('Y'); zlabel('Z');
grid on;
axis equal;

step = 50;
idx = 1:step:stop;
quiver3(actual(idx, 1), actual(idx, 2), actual(idx, 3), ...
        goal(idx, 1) - actual(idx, 1), ...
        goal(idx, 2) - actual(idx, 2), ...
        goal(idx, 3) - actual(idx, 3), ...
        0, 'r', 'LineWidth', 1.5);