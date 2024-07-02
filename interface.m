classdef interface
    methods(Static)
        function selection = dropdown(options, title)
            % Create a GUI figure
            screen_size = get(0, 'ScreenSize');
            fig_width = 300;
            fig_height = 150;
            fig_x = (screen_size(3) - fig_width) / 2;
            fig_y = (screen_size(4) - fig_height) / 2;
            fig = uifigure('Name', title, 'Position', [fig_x, fig_y, fig_width, fig_height], ...
                           'CloseRequestFcn', @select);
        
            % Create dropdown menu and button
            dropdown = uidropdown(fig, 'Items', options, 'Position', [50, 80, 200, 30]);
            uibutton(fig, 'Text', 'Select', 'Position', [100, 30, 100, 30], 'ButtonPushedFcn', @select);
        
            selection = '';
            uiwait(fig);
        
            % Callback function for select button
            function select(~, ~)
                selection = dropdown.Value;
                uiresume(fig);
                delete(fig);
            end
        end

        function dynamic_plotting(folder_path, filenames)
            NAMES = strcat(["F_x" "F_y" "F_z" "M_x" "M_y" "M_z"], " & Position Versus Time");
            W = 0.032 * 9.8;
            L = 35;

            options = squeeze(split(strrep(filenames, ".mat", ""), "_"));            
            
            % Create a GUI figure
            fig = uifigure('Position', [100 100 150 180]);
        
            selection = options(1, :);
            for i = 1 : size(options, 2)
                uidropdown(fig, 'Position', [10 350 - 50 * i, 150, 30], ...
                    'Items', unique(options(:, i)), ...
                    'ValueChangedFcn', @(src, ~) select(i, src));
            end
            update_plot();
        
            function select(i, src)
                selection(i) = src.Value;
                update_plot();
            end

            function update_plot()
                load(fullfile(folder_path, strcat(strjoin(selection, "_"), ".mat")), ...
                    "time", "forces", "motor_position");

                t = tiledlayout(2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

                for idx = 1:6
                    nexttile(t, idx);
                    if idx <= 3
                        factor = W;
                        yl = "Normalized Force (N)";
                    else
                        factor = W * L;
                        yl = "Normalized Torque (N)";
                    end
                    
                    yyaxis left;
                    formatplot(NAMES(idx), "Time (s)", yl);
                    plot(time, forces(:, idx) / factor);
                    yyaxis right;
                    ylabel("Position (cm)");
                    plot(time, motor_position * 100);
                end
            end
        end
    end
end