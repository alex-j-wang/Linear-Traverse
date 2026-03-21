syms YAW; % degrees
D = 43.832; % diameter of propeller, mm
L = Config.L; % orthogonal motor-center distance, mm

R = D/2;
a = L * sqrt(2) * sind(YAW/2);
theta = acos(a/R);
sector = (2 * theta) / (2 * pi) * pi * R^2;
slice = sector - a * R * sin(theta);
area = 2 * slice;
total = 4 * area;

maximum = subs(total, YAW, 0);

Process.format_plot("Overlap Versus Yaw Angle", "Yaw (deg)", "Normalized Overlap");
fplot(total / maximum, [0 60]);
print(gcf, "overlap.svg", "-dsvg");
