% --------------------------------------------------------------------
% Class providing methods for creating GUI menus and dropdowns
% --------------------------------------------------------------------

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
            NAMES = strcat(Config.NAMES, " & Position Versus Time");
            W = 0.032 * 9.8;
            L = 35;
        
            options = squeeze(split(strrep(filenames, ".mat", ""), "_"));
        
            % Create a GUI figure with a grid layout
            screen_size = get(0, 'ScreenSize');
            fig = uifigure('Name', 'Dynamic Lift Force Plotting', ...
                'Position', [0 0 screen_size(3) screen_size(4)]);
        
            % Create a grid layout
            plot_grid = uigridlayout(fig, [1, 2]);
            plot_grid.RowHeight = {'1x'};
            plot_grid.ColumnWidth = {150, '1x'};
        
            % Panel for dropdowns
            dropdown_panel = uipanel(plot_grid);
            dropdown_panel.Layout.Row = 1;
            dropdown_panel.Layout.Column = 1;
        
            % Panel for plots
            plot_panel = uipanel(plot_grid);
            plot_panel.Layout.Row = 1;
            plot_panel.Layout.Column = 2;

             % Initialize tiled layout for plots
            t = tiledlayout(plot_panel, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
        
            selection = options(1, :);
            for i = 1:size(options, 2)
                drop_y = screen_size(4) - 200 - 40 * i;
                uidropdown(dropdown_panel, 'Position', [10 drop_y 200 30], ...
                    'Items', unique(options(:, i)), ...
                    'ValueChangedFcn', @(src, ~) select(i, src));
            end
            update_plot();
        
            function select(i, src)
                selection(i) = src.Value;
                update_plot();
            end
        
            function update_plot()
                % Clear existing tiles
                delete(t.Children);

                % Load data or return if file does not exist
                filename = fullfile(folder_path, strjoin(selection, "_") + ".mat");
                if ~exist(filename, 'file')
                    return;
                end
                load(filename, "time", "forces", "pos_encoder");
        
                for idx = 1:6
                    ax = nexttile(t, idx);
                    if idx <= 3
                        factor = W;
                        yl = "Normalized Force (N)";
                    else
                        factor = W * L;
                        yl = "Normalized Torque (N)";
                    end
        
                    yyaxis(ax, 'left');
                    plot(ax, time, forces(:, idx) / factor);
                    ylabel(ax, yl);
            
                    yyaxis(ax, 'right');
                    plot(ax, time, pos_encoder * 100);
                    ylabel(ax, "Position (cm)");
            
                    title(ax, NAMES(idx));
                    xlabel(ax, "Time (s)");
                    grid(ax, 'on');
                end
            end
        end
    end
end