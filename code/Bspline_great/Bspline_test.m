% version 1.0 --Jan/2025
% version 2.0 --Feb/2025

% written by ma200 (3244613451@qq.com)



% Clean up
clear; close all;

% Read the two input images
I2 = imread("path_to_your_image"); 
I1 = imread("path_to_your_image"); 

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

    % Record the size and position of non-zero regions
    fprintf('I1 Size: [%d, %d], Non-zero region: [%d:%d, %d:%d]\n', size(I1_rgb, 1), size(I1_rgb, 2), min_row1, max_row1, min_col1, max_col1);
    fprintf('I2 Size: [%d, %d], Non-zero region: [%d:%d, %d:%d]\n', size(I2_rgb, 1), size(I2_rgb, 2), min_row2, max_row2, min_col2, max_col2);

    % Crop I1 and I2 to the bounding box of non-zero regions
    I1_cropped = I1_rgb(min_row1:max_row1, min_col1:max_col1, :);
    I2_cropped = I2_rgb(min_row2:max_row2, min_col2:max_col2, :);

    % Display the cropped regions of I1 and I2
    figure;
    subplot(2, 2, 1), imshow(I1_cropped); title('Cropped Image 1 (Non-zero region)');
    subplot(2, 2, 2), imshow(I2_cropped); title('Cropped Image 2 (Non-zero region)');

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

    % Optimizer parameters
    optim = struct('Display', 'iter', 'GradObj', 'on', 'MaxIter', 30, 'DiffMinChange', 0.01, 'DiffMaxChange', 1);

    % Reshape O_trans from a matrix to a vector
    sizes_r = size(O_trans_r); O_trans_r = O_trans_r(:);
    sizes_g = size(O_trans_g); O_trans_g = O_trans_g(:);
    sizes_b = size(O_trans_b); O_trans_b = O_trans_b(:);

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

    % Display the deformed (transformed) cropped image 1
    figure;
    subplot(2, 2, 3), imshow(Icor_rgb); title('Deformed Cropped Image 1 (B-spline)');

    % Resize the transformed image to match the size of I1
    Icor_rgb_resized = imresize(Icor_rgb, [size(I1_rgb, 1), size(I1_rgb, 2)]);

    % Create a black background (same size as I1)
    I1_registered = zeros(size(I1_rgb));

    % Place the deformed image into the same position as the original I1's location
    I1_registered(min_row1:max_row1, min_col1:max_col1, :) = Icor_rgb_resized(min_row1:max_row1, min_col1:max_col1, :);

    % Show the registration results
    figure;
    subplot(2, 2, 1), imshow(I1_rgb); title('Input Image 1 (RGB)');
    subplot(2, 2, 2), imshow(I2_rgb); title('Input Image 2 (RGB)');
    subplot(2, 2, 3), imshow(I1_registered); title('Registered Image (Deformed Image 1 on Black Background)');

else
    % If grayscale images are provided, similar steps can be done.
    % Code for grayscale images will be similar, just working with single channels.
end
