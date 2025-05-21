clear; close all; clc;
% Setup
directory = 'Z:\microplastic_project\TME131-Mikroplast-Git\stranding';
filePattern = fullfile(directory, '*output.nc');
ncFiles = dir(filePattern);
num_files = length(ncFiles);
cityColors = jet(num_files);
city_names = cell(num_files,1);
% Domain box
lat_box = [53.5, 53.5, 61, 61, 53.5];
lon_box = [9.5, 30.5, 30.5, 9.5, 9.5];
% Color definitions for second plot
statusColors.stranded = [1 0 0];
statusColors.active = [0 0 1];
statusColors.out = [0 0.5 0];
% Data storage
all_final_lats = [];
all_final_lons = [];
city_color_list = [];
status_color_list = [];
counts = struct('stranded', zeros(num_files,1), ...
                'active', zeros(num_files,1), ...
                'out', zeros(num_files,1));
global_status_counts = struct('stranded', 0, 'active', 0, 'out', 0);
% Process each file
for k = 1:num_files
    fpath = fullfile(directory, ncFiles(k).name);
    [~, fname, ~] = fileparts(ncFiles(k).name);
    city_names{k} = strrep(fname, '_stranding_output', '');
    city_color = cityColors(k,:);

    try
        lon = ncread(fpath, 'lon');
        lat = ncread(fpath, 'lat');
        status = ncread(fpath, 'status');
        n_particles = size(lon, 2);
        final_lat = NaN(1, n_particles);
        final_lon = NaN(1, n_particles);
        city_col = repmat(city_color, n_particles, 1);
        status_col = zeros(n_particles, 3);
        for i = 1:n_particles
            s_idx = find(status(:, i) == 1, 1, 'first');
            if ~isempty(s_idx)
                f_lat = lat(s_idx, i);
                f_lon = lon(s_idx, i);
            else
                f_lat = lat(end, i);
                f_lon = lon(end, i);
            end
            final_lat(i) = f_lat;
            final_lon(i) = f_lon;
            if f_lat <= 53.5 || f_lat >= 61 || f_lon <= 9.5 || f_lon >= 30.5
                status_col(i,:) = statusColors.out;
                counts.out(k) = counts.out(k) + 1;
                global_status_counts.out = global_status_counts.out + 1;
            elseif ~isempty(s_idx)
                status_col(i,:) = statusColors.stranded;
                counts.stranded(k) = counts.stranded(k) + 1;
                global_status_counts.stranded = global_status_counts.stranded + 1;
            else
                status_col(i,:) = statusColors.active;
                counts.active(k) = counts.active(k) + 1;
                global_status_counts.active = global_status_counts.active + 1;
            end
        end
        all_final_lats = [all_final_lats, final_lat];
        all_final_lons = [all_final_lons, final_lon];
        city_color_list = [city_color_list; city_col];
        status_color_list = [status_color_list; status_col];
    catch ME
        warning('Failed to process %s: %s', ncFiles(k).name, ME.message);
    end
end
% Print summary
fprintf('\nSummary per city:\n');
for k = 1:num_files
    fprintf('%s: Out = %d, Stranded = %d, Active = %d\n', ...
        city_names{k}, counts.out(k), counts.stranded(k), counts.active(k));
end
%% === PLOTTING AND EXPORTING ===
% Plot 1: Colored by City
figure1 = figure('Units','normalized','OuterPosition',[0.1 0.1 0.6 0.7]);
ax1 = geoaxes(figure1);
geolimits(ax1, [53 61.5], [9 31]);
geobasemap(ax1, 'satellite'); hold(ax1, 'on');
geoscatter(ax1, all_final_lats, all_final_lons, 10, city_color_list, 'filled');
geoplot(ax1, lat_box, lon_box, 'k:', 'LineWidth', 3);
title(ax1, 'Final Particle Positions by City');
h_legend = gobjects(num_files,1);
for i = 1:num_files
    h_legend(i) = geoscatter(ax1, NaN, NaN, 10, cityColors(i,:), 'filled');
end
lgd1 = legend(ax1, h_legend, city_names, ...
    'Location', 'southeast', 'Box', 'on', 'FontSize', 10);
lgd1.Color = 'white';
exportgraphics(ax1, fullfile(directory, 'final_positions_by_city.png'), 'Resolution', 300);
% Plot 2: Colored by Status
figure2 = figure('Units','normalized','OuterPosition',[0.1 0.1 0.6 0.7]);
ax2 = geoaxes(figure2);
geolimits(ax2, [53 61.5], [9 31]);
geobasemap(ax2, 'satellite'); hold(ax2, 'on');
geoscatter(ax2, all_final_lats, all_final_lons, 10, status_color_list, 'filled');
geoplot(ax2, lat_box, lon_box, 'k:', 'LineWidth', 3);
title(ax2, 'Final Particle Positions by Status');
legend_entries = {
    sprintf('Stranded (%d)', global_status_counts.stranded), ...
    sprintf('Active (%d)', global_status_counts.active), ...
    sprintf('Out of bounds (%d)', global_status_counts.out)
};
legend_colors = [statusColors.stranded; statusColors.active; statusColors.out];
h2 = gobjects(3,1);
for i = 1:3
    h2(i) = geoscatter(ax2, NaN, NaN, 10, legend_colors(i,:), 'filled');
end
lgd2 = legend(ax2, h2, legend_entries, ...
    'Location', 'southeast', 'Box', 'on', 'FontSize', 10);
lgd2.Color = 'white';
exportgraphics(ax2, fullfile(directory, 'final_positions_by_status.png'), 'Resolution', 300);
% Bar Plot
figure3 = figure('Units','normalized','OuterPosition',[0.1 0.1 0.6 0.6]);
bar([counts.out, counts.stranded, counts.active], 'grouped');
set(gca, 'XTickLabel', city_names, 'XTickLabelRotation', 45);
ylabel('Number of Particles');
title('Particle Status per City');
lgd3 = legend({'Out of Bounds', 'Stranded', 'Active'}, ...
    'Location', 'northeast', 'Box', 'on', 'FontSize', 10);
lgd3.Color = 'white';
grid on;
exportgraphics(gca, fullfile(directory, 'particle_status_per_city.png'), 'Resolution', 300);