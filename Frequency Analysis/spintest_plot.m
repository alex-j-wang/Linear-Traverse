clear; clc; close all hidden;

Process.format_plot("Rotor Frequency Versus Throttle", "Throttle (\%)", "Frequency (Hz)");
plot([10 20 30 40 50 60 70], [119.975 174.325 218.55 248.85 282.175 308.95 334.275], ...
    'DisplayName', 'Traverse CF', 'Marker', '.', 'MarkerSize', 15, 'LineWidth', 1.5);
plot([10 20 30 40 50 60 70], [116.925 170.25 210.025 229.875 258.125 291.75 314.275], ...
    'DisplayName', 'Transducer CF', 'Marker', '.', 'MarkerSize', 15, 'LineWidth', 1.5);

legend('Location', 'southeast')