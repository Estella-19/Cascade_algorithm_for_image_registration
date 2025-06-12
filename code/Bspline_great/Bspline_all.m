% version 1.0 --Nov/2024
% version 2.0 --Jan/2025
% version 3.0 --Mar/2025

% written by ma200 (3244613451@qq.com)



% Clean up
clear; close all;

% Folder containing the images to be registered
input_folder = "path_to_your_files";  
output_folder = "path_to_your_files";  

% Standard image (reference image)
I2 = imread("path_to_your_image");

% Check if the output folder exists, if not, create it
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

% Get list of all image files in the folder
image_files = dir(fullfile(input_folder, '*.png'));  

% Initialize the total registration time
total_registration_time = 0;

% Loop over each image in the folder
for k = 1:length(image_files)
    % Read the input image to be registered
    I1 = imread(fullfile(input_folder, image_files(k).name)); 
    
    % Start measuring the registration time
    tic;

    % Check if the images are RGB or grayscale
    if size(I1, 3) == 3 && size(I2, 3) == 3
        I1_rgb = im2double(I1);
        I2_rgb = im2double(I2);

        % Extract the non-zero regions from I1 and I2
        mask1 = sum(I1_rgb, 3) > 0; 
        mask2 = sum(I2_rgb, 3) > 0; 

        % Find the bounding box of non-zero regions in I1 and I2
        [rows1, cols1] = find(mask1); 
        [rows2, cols2] = find(mask2); 
        min_row1 = min(rows1); max_row1 = max(rows1);
        min_col1 = min(cols1); max_col1 = max(cols1);
        min_row2 = min(rows2); max_row2 = max(rows2);
        min_col2 = min(cols2); max_col2 = max(cols2);

        % Crop I1 and I2 to the bounding box of non-zero regions
        I1_cropped = I1_rgb(min_row1:max_row1, min_col1:max_col1, :);
        I2_cropped = I2_rgb(min_row2:max_row2, min_col2:max_col2, :);

        % Resize I1 cropped region to match the size of I2 cropped region
        I1_resized = imresize(I1_cropped, [size(I2_cropped, 1), size(I2_cropped, 2)]);

        % Type of registration error used
        options.type = 'sd';
        options.centralgrad = false; 

        % B-spline grid spacing in x and y direction
        Spacing = [4 4];

        % Create Initial b-spline grid for RGB channels
        [O_trans_r] = make_init_grid(Spacing, size(I1_resized(:,:,1)));
        [O_trans_g] = make_init_grid(Spacing, size(I1_resized(:,:,2)));
        [O_trans_b] = make_init_grid(Spacing, size(I1_resized(:,:,3)));

        % Convert all values to type double
        I1_resized_r = double(I1_resized(:,:,1)); I2_cropped_r = double(I2_cropped(:,:,1));
        I1_resized_g = double(I1_resized(:,:,2)); I2_cropped_g = double(I2_cropped(:,:,2));
        I1_resized_b = double(I1_resized(:,:,3)); I2_cropped_b = double(I2_cropped(:,:,3));

        O_trans_r = double(O_trans_r);
        O_trans_g = double(O_trans_g);
        O_trans_b = double(O_trans_b);

        % Smooth both channels for faster registration
        I1s_r = imfilter(I1_resized_r, fspecial('gaussian'));
        I2s_r = imfilter(I2_cropped_r, fspecial('gaussian'));
        I1s_g = imfilter(I1_resized_g, fspecial('gaussian'));
        I2s_g = imfilter(I2_cropped_g, fspecial('gaussian'));
        I1s_b = imfilter(I1_resized_b, fspecial('gaussian'));
        I2s_b = imfilter(I2_cropped_b, fspecial('gaussian'));

        optim = struct('Display', 'iter', 'GradObj', 'on', 'MaxIter', 2, 'DiffMinChange', 0.01, 'DiffMaxChange', 1);

        sizes_r = size(O_trans_r); O_trans_r = O_trans_r(:);
        sizes_g = size(O_trans_g); O_trans_g = O_trans_g(:);
        sizes_b = size(O_trans_b); O_trans_b = O_trans_b(:);

        % Start the b-spline nonrigid registration optimizer for R, G, and B channels
        O_trans_r = fminsd(@(x)bspline_registration_gradient(x, sizes_r, Spacing, I1s_r, I2s_r, options), O_trans_r, optim);
        O_trans_r = reshape(O_trans_r, sizes_r);
        Icor_r = bspline_transform(O_trans_r, I1_resized_r, Spacing);

        O_trans_g = fminsd(@(x)bspline_registration_gradient(x, sizes_g, Spacing, I1s_g, I2s_g, options), O_trans_g, optim);
        O_trans_g = reshape(O_trans_g, sizes_g);
        Icor_g = bspline_transform(O_trans_g, I1_resized_g, Spacing);

        O_trans_b = fminsd(@(x)bspline_registration_gradient(x, sizes_b, Spacing, I1s_b, I2s_b, options), O_trans_b, optim);
        O_trans_b = reshape(O_trans_b, sizes_b);
        Icor_b = bspline_transform(O_trans_b, I1_resized_b, Spacing);

        % Combine the registered channels into a single RGB image
        Icor_rgb = cat(3, Icor_r, Icor_g, Icor_b);

        Icor_rgb_resized = imresize(Icor_rgb, [size(I2_cropped, 1), size(I2_cropped, 2)]);

        % Create a black background (same size as I1)
        I1_registered = zeros(size(I1_rgb));

        I1_registered(min_row2:max_row2, min_col2:max_col2, :) = Icor_rgb_resized;

        output_filename = fullfile(output_folder, ['registered_' image_files(k).name]);
        imwrite(I1_registered, output_filename);

        % Measure the elapsed time for this registration
        elapsed_time = toc;
        fprintf('Registration of %s took %.2f seconds.\n', image_files(k).name, elapsed_time);

        % Add to the total registration time
        total_registration_time = total_registration_time + elapsed_time;
    else
        disp('Unsupported image format (grayscale not implemented in this version).');
    end
end

fprintf('Total registration time for all images: %.2f seconds.\n', total_registration_time);
