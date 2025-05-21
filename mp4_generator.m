clear; close all; clc;
% Setup
directory = 'Z:\microplastic_project\TME131-Mikroplast-Git\stranding_Wind'; % User-defined directory
filePattern = fullfile(directory, '*output.nc');
ncFiles = dir(filePattern);
num_files_found = length(ncFiles);
if num_files_found == 0
    disp('No .nc files found in the specified directory. Exiting.');
    return;
end
% --- Custom City Colors Setup (from original script) ---
userDefinedCityColors = [
    0.00 0.00 0.00; % MATLAB Black (e.g., for file 1, Copenhagen)
    1.00 0.65 0.00; % MATLAB Orange (e.g., for file 2, Gdansk)
    1.00 1.00 0.00; % MATLAB Yellow (e.g., for file 3, Gothenburg)
    1.00 1.00 1.00; % MATLAB White (e.g., for file 4, Helsinki) % Note: White might be hard to see on some basemaps
    0.50 0.50 0.50; % MATLAB Grey (e.g., for file 5, Oder)
    0.00 1.00 1.00; % MATLAB Cyan (e.g., for file 7, Oslo)
    0.00 1.00 0.00; % MATLAB Green (e.g., for file 7, Riga)
    1.00 0.00 1.00; % Pure Magenta (e.g., for file 8, St Petersburg)
    0.00 0.00 1.00; % Pure Blue (e.g., for file 9, Stockholm)
    1.00 0.00 0.00; % Pure Red (e.g., for file 10, Visby)
];
cityColors_found = zeros(num_files_found, 3);
if num_files_found > 0
    if isempty(userDefinedCityColors)
        warning('userDefinedCityColors is empty. Defaulting to jet colormap for city colors.');
        cityColors_found = jet(num_files_found);
    else
        num_custom_colors = size(userDefinedCityColors, 1);
        if num_custom_colors == 0
            warning('userDefinedCityColors is defined but has no colors. Defaulting to jet colormap.');
            cityColors_found = jet(num_files_found);
        else
            for i = 1:num_files_found
                cityColors_found(i, :) = userDefinedCityColors(mod(i-1, num_custom_colors) + 1, :);
            end
            if num_custom_colors < num_files_found
                fprintf('INFO: %d custom colors were defined, but there are %d files.\n      The custom colors have been cycled to cover all files.\n', num_custom_colors, num_files_found);
            elseif num_custom_colors > num_files_found
                fprintf('INFO: %d custom colors were defined for %d files.\n      Only the first %d custom colors were used.\n', num_custom_colors, num_files_found, num_files_found);
            end
        end
    end
end
% --- End Custom City Colors Setup ---
% Data storage for animation
all_particle_tracks = cell(num_files_found, 1);
city_names_loaded = cell(num_files_found, 1);
seeding_lats_loaded = NaN(num_files_found, 1);
seeding_lons_loaded = NaN(num_files_found, 1);
max_time_steps = 0;
num_valid_files = 0; % Counter for successfully processed files
disp('Processing NetCDF files...');
for k = 1:num_files_found
    fpath = fullfile(directory, ncFiles(k).name);
    [~, fname, ~] = fileparts(ncFiles(k).name);

    % Extract city name
    split_parts = split(fname, '_');
    current_city_name = split_parts{1};

    try
        lon_data = ncread(fpath, 'lon'); % Expected dimensions: [time, particles]
        lat_data = ncread(fpath, 'lat'); % Expected dimensions: [time, particles]
        % status_data = ncread(fpath, 'status'); % Read if needed for other logic, not directly for animation plotting
        if isempty(lon_data) || isempty(lat_data)
            warning('Longitude or latitude data is empty for file: %s. Skipping this file.', ncFiles(k).name);
            continue;
        end

        if size(lon_data,1) ~= size(lat_data,1) || size(lon_data,2) ~= size(lat_data,2)
            warning('Latitude and longitude dimensions do not match for file: %s. Skipping this file.', ncFiles(k).name);
            continue;
        end
        num_valid_files = num_valid_files + 1;

        all_particle_tracks{num_valid_files}.lats = lat_data;
        all_particle_tracks{num_valid_files}.lons = lon_data;
        all_particle_tracks{num_valid_files}.color = cityColors_found(k,:); % Use color from original file index
        all_particle_tracks{num_valid_files}.name = current_city_name;

        current_num_time_steps = size(lat_data, 1);
        if current_num_time_steps > max_time_steps
            max_time_steps = current_num_time_steps;
        end
        all_particle_tracks{num_valid_files}.num_time_steps = current_num_time_steps;
        all_particle_tracks{num_valid_files}.num_particles = size(lat_data, 2);

        % Store seeding location (initial position of the first particle as a proxy)
        if size(lat_data,1) > 0 && size(lon_data,1) > 0 && size(lon_data,2) > 0 % Removed check for size(lat_data,2) > 0 as it's redundant.
            seeding_lats_loaded(num_valid_files) = lat_data(1, 1);
            seeding_lons_loaded(num_valid_files) = lon_data(1, 1);
        else
             seeding_lats_loaded(num_valid_files) = NaN;
             seeding_lons_loaded(num_valid_files) = NaN;
        end
        city_names_loaded{num_valid_files} = current_city_name;
        fprintf('Successfully processed: %s (%d particles, %d time steps)\n', ncFiles(k).name, size(lat_data,2), current_num_time_steps);
    catch ME
        warning('Failed to process file %s: %s. Skipping this file.', ncFiles(k).name, ME.message);
    end
end
% Trim cell arrays to actual number of valid files
all_particle_tracks = all_particle_tracks(1:num_valid_files);
city_names_loaded = city_names_loaded(1:num_valid_files);
seeding_lats_loaded = seeding_lats_loaded(1:num_valid_files);
seeding_lons_loaded = seeding_lons_loaded(1:num_valid_files);
if num_valid_files == 0
    disp('No valid data loaded from any file. Cannot create animation.');
    return;
end
if max_time_steps == 0
    disp('Maximum time steps is 0 (e.g. all files had empty time series). Cannot create animation.');
    return;
end
disp(['Total valid files processed: ', num2str(num_valid_files)]);
disp(['Maximum time steps for animation: ', num2str(max_time_steps)]);
% --- Animation Setup ---
disp('Setting up animation figure...');
anim_fig = figure('Units','normalized','OuterPosition',[0.05 0.05 0.7 0.85]); % Adjusted size for better map view
ax_anim = geoaxes(anim_fig);
geolimits(ax_anim, [53 61.5], [9 31]); % Domain limits
geobasemap(ax_anim, 'satellite'); % Or 'streets-light', 'grayland', etc.
hold(ax_anim, 'on');
% Plot domain box (static)
lat_box = [53.5, 53.5, 61, 61, 53.5];
lon_box = [9.5, 30.5, 30.5, 9.5, 9.5];
geoplot(ax_anim, lat_box, lon_box, 'w:', 'LineWidth', 2, 'HandleVisibility', 'off'); % Added HandleVisibility
% Plot seeding locations (static)
markerSizeSeeding = 100;
for i = 1:num_valid_files
    if ~isnan(seeding_lats_loaded(i)) && ~isnan(seeding_lons_loaded(i))
        geoscatter(ax_anim, seeding_lats_loaded(i), seeding_lons_loaded(i), ...
                   markerSizeSeeding, all_particle_tracks{i}.color, 'filled', ...
                   'Marker', 'p', ... % Pentagram
                   'MarkerEdgeColor', 'k', ...
                   'HandleVisibility', 'off'); % Prevent seeding markers from appearing in legend by default
    end
end
% Create legend (static)
h_legend_proxies = gobjects(num_valid_files,1);
legend_city_names = cell(num_valid_files,1);
for i = 1:num_valid_files
    % Dummy scatter for legend. These handles WILL be used for the legend.
    h_legend_proxies(i) = geoscatter(ax_anim, NaN, NaN, 10, all_particle_tracks{i}.color, 'filled');
    legend_city_names{i} = all_particle_tracks{i}.name;
end
if ~isempty(h_legend_proxies) && all(isgraphics(h_legend_proxies)) && num_valid_files > 0
    % Ensure legend_city_names has the correct number of entries for h_legend_proxies
    valid_legend_indices = 1:num_valid_files; % Assuming all proxies are valid

    lgd = legend(ax_anim, h_legend_proxies(valid_legend_indices), legend_city_names(valid_legend_indices), ...
           'Location', 'southeast', 'Box', 'on', 'FontSize', 9);
    lgd.Color = [0.95 0.95 0.95]; % Slightly off-white for legend background
    lgd.TextColor = [0.1 0.1 0.1];
else
    disp('Could not create legend for animation or no valid files to legend.');
end

% --- MP4 saving setup ---
mp4_filename = fullfile(directory, 'particle_drift_animation_speedup.mp4');
% Adjust framerate to achieve desired duration. The VideoWriter object uses FrameRate.
target_duration_seconds_min = 30; % Minimum desired MP4 length in seconds
target_duration_seconds_max = 60; % Maximum desired MP4 length in seconds

% Calculate frame skip and target framerate
frame_skip = 1; % Initialize frame skip to 1 (no skipping)
if max_time_steps > 0
    % Calculate the total number of frames we would ideally write to hit the target duration
    % at a reasonable framerate (e.g., 25-30 fps for smooth video)
    ideal_framerate = 25; % frames per second
    max_frames_for_duration = target_duration_seconds_max * ideal_framerate;

    if max_time_steps > max_frames_for_duration
        frame_skip = ceil(max_time_steps / max_frames_for_duration);
    end
end

actual_frames_to_write = floor(max_time_steps / frame_skip);
if actual_frames_to_write == 0 && max_time_steps > 0
    actual_frames_to_write = 1; % Ensure at least one frame is written if data exists
    frame_skip = max_time_steps; % Skip all but the first frame
end

% Calculate actual framerate to target the desired duration
if actual_frames_to_write > 0
    % Aim for the middle of the target duration range
    target_duration = (target_duration_seconds_min + target_duration_seconds_max) / 2;
    frame_rate = actual_frames_to_write / target_duration;
    if frame_rate < 1 % Ensure at least 1 fps if actual frames is very low
        frame_rate = 1;
    end
else
    frame_rate = 1; % Default if no frames to write
end

fprintf('Calculated frame skip: %d. This will result in approximately %d frames being written.\n', frame_skip, actual_frames_to_write);
fprintf('Calculated framerate for MP4: %f frames per second.\n', frame_rate);

% Create VideoWriter object
try
    writerObj = VideoWriter(mp4_filename, 'MPEG-4');
    writerObj.FrameRate = frame_rate;
    open(writerObj);
catch ME
    warning('Failed to initialize VideoWriter: %s. Animation will not be saved to MP4.', ME.message);
    writerObj = []; % Set to empty to skip writing frames
end

disp(['Starting animation generation (this may take a while for ', num2str(max_time_steps), ' frames)...']);
scatter_handles_in_frame = []; % To store handles of scatter objects in the current frame
% Initialize storage for the last valid position of each particle for each file
last_valid_lats = cell(num_valid_files, 1);
last_valid_lons = cell(num_valid_files, 1);
for i = 1:num_valid_files
    num_particles_in_file = all_particle_tracks{i}.num_particles;
    if all_particle_tracks{i}.num_time_steps > 0
        last_valid_lats{i} = all_particle_tracks{i}.lats(1, :);
        last_valid_lons{i} = all_particle_tracks{i}.lons(1, :);
    else
        last_valid_lats{i} = NaN(1, num_particles_in_file);
        last_valid_lons{i} = NaN(1, num_particles_in_file);
    end
end

frame_count = 0; % Counter for frames actually written to MP4
for t = 1:max_time_steps
    % Only process and write a frame if it's a "skipped" frame
    if mod(t - 1, frame_skip) == 0 % t-1 because mod(0,X) is 0. This ensures frame 1 is always processed.
        frame_count = frame_count + 1;
        % Delete scatter plots from the previous frame
        if ~isempty(scatter_handles_in_frame)
            for h_idx = 1:length(scatter_handles_in_frame)
                if isgraphics(scatter_handles_in_frame(h_idx))
                    delete(scatter_handles_in_frame(h_idx));
                end
            end
        end
        scatter_handles_in_frame = []; % Reset for current frame

        % Plot particles for current time step t
        for i = 1:num_valid_files
            track_data = all_particle_tracks{i};

            current_lats_from_file = NaN(1, track_data.num_particles);
            current_lons_from_file = NaN(1, track_data.num_particles);
            if t <= track_data.num_time_steps % If current time step is within this file's data
                current_lats_from_file = track_data.lats(t, :);
                current_lons_from_file = track_data.lons(t, :);
            end

            % Determine what to plot for current_lats and current_lons
            % Initialize with the last valid known position
            current_lats_to_plot = last_valid_lats{i};
            current_lons_to_plot = last_valid_lons{i};
            % Loop through each particle to decide its current plotted position
            for p_idx = 1:track_data.num_particles
                if ~isnan(current_lats_from_file(p_idx)) && ~isnan(current_lons_from_file(p_idx))
                    % If the current data from the file is valid, use it
                    current_lats_to_plot(p_idx) = current_lats_from_file(p_idx);
                    current_lons_to_plot(p_idx) = current_lons_from_file(p_idx);
                end
                % If current_lats_from_file(p_idx) is NaN, it means the particle
                % either stopped moving or went out of bounds and is no longer reported.
                % In this case, we retain its last_valid_position, which was set
                % from the previous time step.
            end
            % Update last_valid_positions for the next iteration (important, even for skipped frames,
            % so that the "last valid position" is always up-to-date for the *next* plotted frame)
            last_valid_lats{i} = current_lats_to_plot;
            last_valid_lons{i} = current_lons_to_plot;
            % Filter out NaNs for plotting (particles that were never valid or truly went out of display bounds)
            valid_idx_to_plot = ~isnan(current_lats_to_plot) & ~isnan(current_lons_to_plot);

            if any(valid_idx_to_plot)
                % Plot actual particle data; set HandleVisibility to 'off'
                % so these plots don't interfere with the legend.
                h = geoscatter(ax_anim, current_lats_to_plot(valid_idx_to_plot), current_lons_to_plot(valid_idx_to_plot), ...
                               10, track_data.color, 'filled', 'MarkerFaceAlpha', 0.8, ...
                               'HandleVisibility', 'off');
                scatter_handles_in_frame = [scatter_handles_in_frame, h];
            end
        end

        title(ax_anim, sprintf('Particle Positions - Time Step: %d / %d', t, max_time_steps), 'Color', 'white');
        drawnow; % Crucial for updating the figure before capturing

        % Capture frame and write to MP4
        if ~isempty(writerObj)
            frame = getframe(anim_fig);
            writeVideo(writerObj, frame);
        end

        if mod(frame_count, 10) == 0 || frame_count == actual_frames_to_write % Print progress based on written frames
           fprintf('Frame %d of %d written to MP4 (Original time step: %d).\n', frame_count, actual_frames_to_write, t);
        end
    else
        % If we are skipping this frame, we still need to update last_valid_lats/lons
        % so that when the next frame IS plotted, it starts from the correct position.
        for i = 1:num_valid_files
            track_data = all_particle_tracks{i};
            if t <= track_data.num_time_steps % Only update if current time step is within this file's data
                current_lats_from_file = track_data.lats(t, :);
                current_lons_from_file = track_data.lons(t, :);

                % Update last_valid_positions based on the current data from file
                % Particles that become NaN will retain their last valid position
                nan_lats_idx = isnan(current_lats_from_file);
                nan_lons_idx = isnan(current_lons_from_file);
                last_valid_lats{i}(~nan_lats_idx) = current_lats_from_file(~nan_lats_idx);
                last_valid_lons{i}(~nan_lons_idx) = current_lons_from_file(~nan_lons_idx);
            end
        end
    end
end
hold(ax_anim, 'off');

% Close the video writer object
if ~isempty(writerObj)
    close(writerObj);
    disp(['Animation saved to: ', mp4_filename]);
end

disp('Script finished.');
% Optional: Close the figure after saving
% close(anim_fig);