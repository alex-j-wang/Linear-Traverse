% --------------------------------------------------------------------
% Class providing methods for creating GUI menus and dropdowns
% --------------------------------------------------------------------

% [10/26/25] TODO: update to support two force transducers and timetable data format

classdef interface
    methods(Static)
        function selection = dropdown(options, title)
            % DROPDOWN  Create a dropdown menu to select an item from options
            screen_size = get(0, 'ScreenSize');
            fig_width = 300;
            fig_height = 150;
            fig_x = (screen_size(3) - fig_width) / 2;
            fig_y = (screen_size(4) - fig_height) / 2;
            fig = uifigure('Name', title, 'Position', [fig_x, fig_y, fig_width, fig_height], ...
                'CloseRequestFcn', @select);

            % Dropdown menu and button
            dropdown = uidropdown(fig, 'Items', options, 'Position', [50, 80, 200, 30]);
            uibutton(fig, 'Text', 'Select', 'Position', [100, 30, 100, 30], 'ButtonPushedFcn', @select);

            selection = '';
            uiwait(fig);

            function select(~, ~)
                % SELECT  Store the selected item and close the figure
                selection = dropdown.Value;
                uiresume(fig);
                delete(fig);
            end
        end

        function dynamic_plotting(folder_path, filenames)
            % DYNAMIC_PLOTTING  Create a GUI for plotting dynamic data
            if nargin == 1
                items = dir(fullfile(folder_path, '*.mat'));
                filenames = {items.name};
            end
            names = Config.NAMES + ' & Position Versus Time';
            options = sortrows(squeeze(split(strrep(filenames, ".mat", ""), '_')));

            % GUI figure
            screen_size = get(0, 'ScreenSize');
            fig = uifigure('Name', sprintf('Dynamic Plotting | %s', folder_path), ...
                'Position', [0 0 screen_size(3) screen_size(4)]);

            % Grid layout
            plot_grid = uigridlayout(fig, [1, 2]);
            plot_grid.RowHeight = {'1x'};
            plot_grid.ColumnWidth = {150, '1x'};

            % Panel for dropdowns
            option_panel = uipanel(plot_grid);
            option_panel.Layout.Row = 1;
            option_panel.Layout.Column = 1;

            % Panel for plots
            plot_panel = uipanel(plot_grid);
            plot_panel.Layout.Row = 1;
            plot_panel.Layout.Column = 2;

            % Tiled layout for plots
            t = tiledlayout(plot_panel, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

            % Parameter dropdown menus
            selection = [options(1, :)];
            y = screen_size(4) - 200;
            sz = [148 30];
            label('Parameters');
            y = y + 30;
            for i = 1:size(options, 2)
                y = y - 40;
                uidropdown(option_panel, 'Position', [10 y sz], ...
                    'Value', selection(i), ...
                    'Items', unique(options(:, i)), ...
                    'ValueChangedFcn', @(src, ~) select(i, src));
            end

            % Plot configuration checkboxes
            plot_config = [true(1, 3) false(1, 3)];
            y = y - 10;
            for i = 1:6
                y = y - 25;
                if i == 1
                    label('Force Plots');
                elseif i == 5
                    label('Axis Options');
                end
                uicheckbox(option_panel, 'Text', Config.BOXES(i), ...
                    'Position', [20 y sz], 'Value', plot_config(i), ...
                    'ValueChangedFcn', @(src, ~) select(i, src));
            end

            lb = zeros(1, 6);
            ub = zeros(1, 6);

            update_plot();

            function label(text)
                uilabel(option_panel, 'Position', [20 y sz], 'Text', text, 'FontWeight', 'bold');
                y = y - 25;
            end

            function select(i, src)
                % SELECT  Update the selection and plot
                if isa(src, 'matlab.ui.control.DropDown')
                    selection(i) = src.Value;
                else
                    plot_config(i) = src.Value;
                    if i == 5
                        option_panel.Children(1).Enable = ~src.Value;
                    end
                end
                update_plot();
            end

            function update_plot()
                % UPDATE_PLOT  Update the plot based on selected settings
                delete(t.Children);

                % Load data or return if file does not exist
                filename = fullfile(folder_path, strjoin(selection, '_') + ".mat");
                if ~exist(filename, 'file')
                    return;
                end
                load(filename, 'time', 'forces', 'force_start', 'force_end', 'pos_encoder', 'stdev');
        
                for idx = 1:6
                    ax = nexttile(t, idx);
                    if idx <= 3
                        factor = Config.W;
                        yl = 'Normalized Force';
                    else
                        factor = Config.W * Config.L;
                        yl = 'Normalized Torque';
                    end

                    yyaxis(ax, 'right');
                    plot(ax, time, pos_encoder * 100, 'DisplayName', 'Position', 'LineWidth', 1.5);
                    ylabel(ax, 'Position (cm)');
                    ax.YLim = [min(ax.YLim(1), -1) max(ax.YLim(2), 1)];

                    yyaxis(ax, 'left');
                    hold(ax, 'on');
                    for j = 1:4
                        if plot_config(j)
                            fp = Config.BOXES(j);
                            if j == 4
                                yline(ax, force_start(idx) / factor, 'DisplayName', 'Tare Start', 'LineWidth', 1.5);
                                yline(ax, force_end(idx) / factor, 'DisplayName', 'Tare End', 'LineWidth', 1.5);
                            else
                                plot(ax, time, forces.(fp)(:, idx) / factor, 'DisplayName', fp, 'LineWidth', 1.5);
                            end
                            if j == 1
                                select = round(linspace(1, length(time), 50));
                                tt = [time(select); flip(time(select))];
                                yy = [(forces.(fp)(select, idx) + stdev(select, idx));
                                    flip((forces.(fp)(select, idx) - stdev(select, idx)))];
                                fill(ax, tt, yy / factor, ax.Children(1).Color, 'DisplayName', 'μ ± σ', ...
                                    'EdgeColor', 'none', 'FaceAlpha', 0.1);
                            end
                        end
                    end
                    ylabel(ax, yl);
                    if ~plot_config(5)
                        lb(idx) = ax.YLim(1);
                        ub(idx) = ax.YLim(2);
                    end

                    title(ax, names(idx));
                    xlabel(ax, 'Time (s)');
                    grid(ax, 'on');
                    legend(ax);
                end

                if ~plot_config(5) && plot_config(6)
                    lb(1:3) = min(lb(1:3));
                    lb(4:6) = min(lb(4:6));
                    ub(1:3) = max(ub(1:3));
                    ub(4:6) = max(ub(4:6));
                end

                for idx = 1:6
                    ylim(nexttile(t, idx), [lb(idx), ub(idx)]);
                end
            end
        end
    end
end