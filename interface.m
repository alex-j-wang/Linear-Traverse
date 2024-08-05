% --------------------------------------------------------------------
% Class providing methods for creating GUI menus and dropdowns
% --------------------------------------------------------------------

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
                filenames = sort({items.name});
            end
            names = Config.NAMES + ' & Position Versus Time';
            options = squeeze(split(strrep(filenames, '.mat', ''), '_'));
        
            % GUI figure
            screen_size = get(0, 'ScreenSize');
            fig = uifigure('Name', 'Dynamic Lift Force Plotting', ...
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
                    'Items', unique(options(:, i)), ...
                    'ValueChangedFcn', @(src, ~) refresh(i, src.Value));
            end
            
            % Plot configuration checkboxes
            visibility = repmat(matlab.lang.OnOffSwitchState.on, 1, 4);
            locked = false;
            equalized = false;
            y = y - 35;
            label('Force Plots');
            for i = 1:4
                uicheckbox(option_panel, 'Text', Config.FORCES(i), ...
                    'Position', [20 y sz], 'Value', visibility(i), ...
                    'ValueChangedFcn', @(src, ~) toggle_force(i, src.Value));
                y = y - 25;
            end
            label('Axis Options');
            uicheckbox(option_panel, 'Text', "Lock", ...
                'Position', [20 y sz], 'Value', locked, ...
                'ValueChangedFcn', @(src, ~) lock(src.Value));
            y = y - 25;
            uicheckbox(option_panel, 'Text', "Equalize", ...
                'Position', [20 y sz], 'Value', equalized, ...
                'ValueChangedFcn', @(src, ~) set_axes(src.Value));
            
            lb = zeros(1, 6);
            ub = zeros(1, 6);

            refresh();

            function label(text)
                uilabel(option_panel, 'Position', [20 y sz], 'Text', text, 'FontWeight', 'bold');
                y = y - 25;
            end

            function toggle_force(i, val)
                % TOGGLE_FORCE  Toggle the visibility of a force plot
                visibility(i) = val;
                for idx = 1:6
                    ax = nexttile(t, idx);
                    ax.Children(5 - i).Visible = visibility(i);
                end
                if ~locked
                    set_axes(equalized);
                end
            end

            function set_axes(val)
                % SET_AXES  Set the axes of all plots
                equalized = val;
                for idx = 1:6
                    ax = nexttile(t, idx);
                    set(ax, 'YLimMode', 'auto');
                    lb(idx) = ax.YLim(1);
                    ub(idx) = ax.YLim(2);
                end
                if ~equalized
                    return
                end
                lb(1:3) = min(lb(1:3));
                lb(4:6) = min(lb(4:6));
                ub(1:3) = max(ub(1:3));
                ub(4:6) = max(ub(4:6));
                for idx = 1:6
                    ax = nexttile(t, idx);
                    ylim(ax, [lb(idx) ub(idx)]);
                end
            end

            function lock(val)
                % LOCK  Lock the axes of all plots
                locked = val;
                option_panel.Children(1).Enable = ~locked;
                if locked
                    for idx = 1:6
                        ax = nexttile(t, idx);
                        set(ax, 'YLimMode', 'manual');
                    end
                else
                    set_axes(equalized);
                end
            end
        
            function refresh(i, val)
                % REFRESH  Update the plot based on selected settings
                if nargin
                    selection(i) = cellstr(val);
                end
                delete(t.Children);

                % Load data or return if file does not exist
                filename = fullfile(folder_path, strjoin(selection, '_') + ".mat");
                if ~exist(filename, 'file')
                    return;
                end
                load(filename, 'time', 'forces', 'tare_forces', 'pos_encoder');

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
            
                    yyaxis(ax, 'left');
                    hold(ax, 'on');
                    for j = 1:4
                        fp = Config.FORCES(j);
                        if j == 4
                            yline(ax, tare_forces(idx) / factor, 'DisplayName', fp, 'LineWidth', 1.5);
                        else
                            plot(ax, time, forces.(fp)(:, idx) / factor, 'DisplayName', fp, 'LineWidth', 1.5);
                        end
                        ax.Children(1).Visible = visibility(j);
                    end
                    ylabel(ax, yl);
            
                    title(ax, names(idx));
                    xlabel(ax, 'Time (s)');
                    grid(ax, 'on');
                    legend(ax);
                end
                if locked
                    for idx = 1:6
                        ax = nexttile(t, idx);
                        ylim(ax, [lb(idx) ub(idx)]);
                    end
                else
                    set_axes(equalized);
                end
            end
        end
    end
end