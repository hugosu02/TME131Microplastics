clear; close all; clc;

% Setup
directory = 'Z:\microplastic_project\TME131-Mikroplast-Git\stranding_noWind';
filePattern = fullfile(directory, '*output.nc');
ncFiles = dir(filePattern);
num_files = length(ncFiles);

% --- MODIFICATION FOR CUSTOM CITY COLORS START ---
% Define your custom colors here as an N-by-3 matrix (RGB values between 0 and 1).
% The order of colors corresponds to the order of files read.
% For example, if you have 3 files and want them to be red, green, and blue respectively:
% userDefinedCityColors = [
%     1 0 0;   % Red for the first file/city
%     0 1 0;   % Green for the second file/city
%     0 0 1;   % Blue for the third file/city
% ];
%
% If you have fewer custom colors defined than the number of files,
% the colors will be cycled. For example, if you define 3 colors but have 4 files,
% the 4th file will use the 1st color.
% If you define more custom colors than files, only the necessary number of
% initial colors will be used.
%
% Below is an example list of 10 colors. Adjust this list as needed.
userDefinedCityColors = [
    0.00 0.00 0.00; % MATLAB Black (e.g., for file 1, Copenhagen)
    1.00 0.65 0.00; % MATLAB Orange (e.g., for file 2, Gdansk)
    1.00 1.00 0.00; % MATLAB Yellow (e.g., for file 3, Gothenburg)
    1.00 1.00 1.00; % MATLAB White (e.g., for file 4, Helsinki)
    0.50 0.50 0.50; % MATLAB Grey (e.g., for file 5, Oder)
    0.00 1.00 1.00; % MATLAB Cyan (e.g., for file 7, Oslo)
    0.00 1.00 0.00; % MATLAB Green (e.g., for file 7, Riga)
    1.00 0.00 1.00; % Pure Magenta (e.g., for file 8, St Petersburg)
    0.00 0.00 1.00; % Pure Blue (e.g., for file 9, Stockholm)
    1.00 0.00 0.00; % Pure Red (e.g., for file 10, Visby)

    % Add more rows if you have more than 10 input files and want unique colors
];

cityColors = zeros(num_files, 3); % Initialize cityColors matrix

if num_files > 0
    if isempty(userDefinedCityColors)
        warning('userDefinedCityColors is empty. Defaulting to jet colormap for city colors.');
        cityColors = jet(num_files);
    else
        num_custom_colors = size(userDefinedCityColors, 1);
        if num_custom_colors == 0 % Should be caught by isempty, but as a safeguard
            warning('userDefinedCityColors is defined but has no colors. Defaulting to jet colormap.');
            cityColors = jet(num_files);
        else
            for i = 1:num_files
                cityColors(i, :) = userDefinedCityColors(mod(i-1, num_custom_colors) + 1, :);
            end
            if num_custom_colors < num_files
                fprintf('INFO: %d custom colors were defined, but there are %d files.\n      The custom colors have been cycled to cover all files.\n', num_custom_colors, num_files);
            elseif num_custom_colors > num_files
                fprintf('INFO: %d custom colors were defined for %d files.\n      Only the first %d custom colors were used.\n', num_custom_colors, num_files, num_files);
            end
        end
    end
else
    disp('No files found to process.');
end
% --- MODIFICATION FOR CUSTOM CITY COLORS END ---

city_names = cell(num_files,1);

% --- MODIFICATION START ---
% Storage for seeding locations
seeding_lats = NaN(num_files, 1);
seeding_lons = NaN(num_files, 1);
% --- MODIFICATION END ---

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
    % Extract only the first part before the first underscore for city name
    split_parts = split(fname, '_');
    city_names{k} = split_parts{1};
    
    % city_color is now correctly assigned from the (potentially custom) cityColors matrix
    city_color = cityColors(k,:);
    
    try
        lon = ncread(fpath, 'lon');
        lat = ncread(fpath, 'lat');
        status = ncread(fpath, 'status');
        
        % --- MODIFICATION START ---
        % Store seeding location (initial position of the first particle)
        if ~isempty(lat) && ~isempty(lon) && size(lat,1) > 0 && size(lon,1) > 0
            seeding_lats(k) = lat(1, 1);
            seeding_lons(k) = lon(1, 1);
        else
            warning('Latitude or longitude data is empty or has insufficient time steps for file: %s. Skipping seeding location.', ncFiles(k).name);
            % seeding_lats(k) and seeding_lons(k) will remain NaN
        end
        % --- MODIFICATION END ---
        
        n_particles = size(lon, 2);
        final_lat = NaN(1, n_particles);
        final_lon = NaN(1, n_particles);
        city_col = repmat(city_color, n_particles, 1);
        status_col = zeros(n_particles, 3);
        
        for i = 1:n_particles
            % Check if status has enough rows for this particle
            if size(status,1) == 0 % No status data for any particle
                if i == 1 % Warn only once per file if status is completely empty
                    warning('Status array is empty for file: %s. Cannot determine stranded status.', ncFiles(k).name);
                end
                s_idx = []; % Treat as not stranded
            elseif size(status,2) < i % Not enough columns in status for this particle
                 if i == 1 % Warn only once per file if status is missing columns
                    warning('Status array has fewer columns than particles for file: %s. Particle %d status unavailable.', ncFiles(k).name, i);
                 end
                 s_idx = []; % Treat as not stranded
            else
                s_idx = find(status(:, i) == 1, 1, 'first');
            end
            
            % Determine final position
            % Ensure lat and lon have data for this particle
            if size(lat,2) < i || size(lon,2) < i
                if i == 1
                    warning('Lat/Lon data has fewer columns than expected n_particles for file: %s. Skipping particle %d.', ncFiles(k).name, i);
                end
                final_lat(i) = NaN; % Mark as invalid
                final_lon(i) = NaN;
                continue; % Skip to next particle
            end
            
            if ~isempty(s_idx) % Stranded
                f_lat = lat(s_idx, i);
                f_lon = lon(s_idx, i);
            else % Not stranded, take last known position
                if size(lat,1) > 0 && size(lon,1) > 0 % Ensure there's at least one time step
                    f_lat = lat(end, i);
                    f_lon = lon(end, i);
                else
                    % This case should ideally be caught by earlier checks on lat/lon for the file
                    f_lat = NaN;
                    f_lon = NaN;
                end
            end
            
            final_lat(i) = f_lat;
            final_lon(i) = f_lon;
            
            if isnan(f_lat) || isnan(f_lon) % If position is invalid, skip status categorization
                continue;
            end
            
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
        
        % Filter out any NaN positions that might have occurred
        valid_indices = ~isnan(final_lat) & ~isnan(final_lon);
        all_final_lats = [all_final_lats, final_lat(valid_indices)];
        all_final_lons = [all_final_lons, final_lon(valid_indices)];
        city_color_list = [city_color_list; city_col(valid_indices,:)];
        status_color_list = [status_color_list; status_col(valid_indices,:)];
        
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
if num_files > 0 && ~isempty(all_final_lats) % Ensure there's data to plot
    % Plot 1: Colored by City
    figure1 = figure('Units','normalized','OuterPosition',[0.1 0.1 0.6 0.7]);
    ax1 = geoaxes(figure1);
    geolimits(ax1, [53 61.5], [9 31]);
    geobasemap(ax1, 'satellite'); hold(ax1, 'on');
    
    % Plot final particle positions (uses city_color_list, which is derived from cityColors)
    geoscatter(ax1, all_final_lats, all_final_lons, 10, city_color_list, 'filled');
    geoplot(ax1, lat_box, lon_box, 'w:', 'LineWidth', 3);
    
    % --- MODIFICATION FOR STAR MARKERS START ---
    % Add markers for seeding locations (uses cityColors directly)
    markerSizeSeeding = 120; 
    for k_seed = 1:num_files
        if ~isnan(seeding_lats(k_seed)) && ~isnan(seeding_lons(k_seed))
            geoscatter(ax1, seeding_lats(k_seed), seeding_lons(k_seed), ...
                       markerSizeSeeding, cityColors(k_seed,:), 'filled', ... % Uses the custom or cycled cityColors
                       'Marker', 'p', ... 
                       'MarkerEdgeColor', 'k'); 
        end
    end
    title(ax1, 'Final Particle Positions by City (Stars indicate Seeding Locations)');
    % --- MODIFICATION FOR STAR MARKERS END ---
    
    h_legend = gobjects(num_files,1);
    for i = 1:num_files
        % Dummy scatter for legend (uses cityColors directly)
        h_legend(i) = geoscatter(ax1, NaN, NaN, 10, cityColors(i,:), 'filled'); % Uses the custom or cycled cityColors
    end
    
    % Filter out city names for which no data was plotted in the legend
    % (e.g., if a file failed to process completely but num_files was > 0)
    % This requires city_names to be correctly populated and correspond to cityColors
    valid_legend_entries = 1:num_files; % Assume all are valid initially
    if length(city_names) < num_files
        warning('Number of city names is less than number of files. Legend might be incomplete.');
        valid_legend_entries = 1:length(city_names);
    end
    
    % Create legend only with valid entries
    if ~isempty(valid_legend_entries) && all(isgraphics(h_legend(valid_legend_entries)))
        lgd1 = legend(ax1, h_legend(valid_legend_entries), city_names(valid_legend_entries), ...
            'Location', 'southeast', 'Box', 'on', 'FontSize', 10);
        lgd1.Color = 'white';
    else
        disp('No valid entries for Plot 1 legend.');
    end
    exportgraphics(ax1, fullfile(directory, 'final_positions_by_city.png'), 'Resolution', 300);

    % Plot 2: Colored by Status
    figure2 = figure('Units','normalized','OuterPosition',[0.1 0.1 0.6 0.7]);
    ax2 = geoaxes(figure2);
    geolimits(ax2, [53 61.5], [9 31]);
    geobasemap(ax2, 'satellite'); hold(ax2, 'on');
    geoscatter(ax2, all_final_lats, all_final_lons, 10, status_color_list, 'filled');
    geoplot(ax2, lat_box, lon_box, 'w:', 'LineWidth', 3);
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
    bar_data = [counts.out, counts.stranded, counts.active];

    if size(bar_data,1) == num_files && ~isempty(city_names)
        % Ensure city_names used for labels matches the actual rows in bar_data
        if length(city_names) == size(bar_data,1)
             bar(bar_data, 'grouped');
             set(gca, 'XTickLabel', city_names, 'XTickLabelRotation', 45);
        else % Fallback if city_names somehow doesn't match due to prior errors
            warning('Mismatch between number of cities and data for bar plot. Plotting without city labels.');
            bar(bar_data, 'grouped');
        end
    else
        warning('Insufficient data or city names for bar plot. Plotting without city labels.');
        bar(bar_data, 'grouped'); % Plot data even if labels are missing
    end

    ylabel('Number of Particles');
    title('Particle Status per City');
    lgd3 = legend({'Out of Bounds', 'Stranded', 'Active'}, ...
        'Location', 'northeast', 'Box', 'on', 'FontSize', 10);
    lgd3.Color = 'white';
    grid on;
    exportgraphics(gca, fullfile(directory, 'particle_status_per_city.png'), 'Resolution', 300);
else
    disp('No data processed or no files found, skipping plots.');
end