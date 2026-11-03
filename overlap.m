syms DPSI; % relative yaw, degrees

D = 51; % diameter of propeller, mm
l = 46; % arm length, mm

R = D/2;
a_1 = l * sind(DPSI/2);
a_2 = l * sind((90 - DPSI)/2);

% overlap between two radius-R disks centered 2a apart
lens = @(a) piecewise(a < R, 2 * R^2 * acos(a/R) - 2 * a * sqrt(R^2 - a^2), 0);

beta = (lens(a_1) + lens(a_2)) / (pi * R^2);
beta_min = double(subs(beta, DPSI, 45));

Process.format_plot("", "$\Delta\psi$ (deg)", "Overlap ratio, $\beta$");
fplot(beta, [0 90]);
plot(45, beta_min, "ko", "MarkerFaceColor", "k");
text(45, beta_min, sprintf("$\\beta_{min} = %.3f$", beta_min), "Interpreter", "latex", ...
    "HorizontalAlignment", "center", "VerticalAlignment", "top", "FontSize", 18);
ylim([0 1]);
print(gcf, "overlap.svg", "-dsvg");
