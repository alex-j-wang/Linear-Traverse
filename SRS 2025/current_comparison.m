clear; clc; close all hidden;

Process.format_plot("", "Thrust (\%)", "Current Measurement (A)");

axis("square");
xlim([0 100]);
set(gcf, 'Renderer', 'painters', 'Position', [100 100 1000 750]);

plot(10:10:100, [450 850 1250 1650 2030 2620 3040 3260 3690 4170] / 1000, ".-", "MarkerSize", 8, "LineWidth", 1.5);
plot(10:10:100, [440 835 1253 1628 2020 2600 3020 3240 3276 3276] / 1000, ".-", "MarkerSize", 8, "LineWidth", 1.5);

legend('Power Supply', 'INA3221', 'Location', 'southeast');

%% Save
exportgraphics(gca, "/Users/alexwang/Downloads/power-comparison.svg", 'ContentType', 'vector');