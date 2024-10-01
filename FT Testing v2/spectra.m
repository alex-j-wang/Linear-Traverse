clear; clc; close all hidden

load('enabled_new.mat');
[pxx1, fxx1] = pwelch(forces(:, 3), [], [], [], Config.SRATE);
load('disabled_new.mat');
[pxx2, fxx2] = pwelch(forces(:, 3), [], [], [], Config.SRATE);

semilogx(fxx1, 10 * log10(pxx1), 'LineWidth', 1.5);
Process.format_plot("Z-Force Frequency Spectra", "Log Frequency (Hz)", "Power Spectral Density (dB)")
semilogx(fxx2, 10 * log10(pxx2), 'LineWidth', 1.5);
legend('Traverse Enabled', 'Traverse Disabled');
