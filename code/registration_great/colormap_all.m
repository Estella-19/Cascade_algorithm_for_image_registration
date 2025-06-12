% version 1.0 --Nov/2024

% written by ma200 (3244613451@qq.com)

clear, clc;
folder_path = "path_to_your_files";  
output_folder = fullfile(getenv('USERPROFILE'), 'Desktop', 'ColormapImageszcf');  

% Get all image files in the folder
image_files = dir(fullfile(folder_path, '*.png'));  

% Loop through each image
for k = 1:length(image_files)
    filename = fullfile(folder_path, image_files(k).name);
    f = imread(filename);
    
    % If image is color, convert to grayscale
    Info = imfinfo(filename);
    if Info.BitDepth > 8
        f = rgb2gray(f); 
    end 
    
    % Display original image
    % figure;
    imshow(f);
    title('Original Grayscale Image');
    
    % Display image using mesh, similar to watershed basins
    % figure;
    mesh(double(f));
    title('3D Surface Plot of the Image');
    
    % Watershed algorithm segmentation
    B = im2bw(f, graythresh(f)); % Binarize; ensure catchment basins have lower values (0)
    b = -B;
    d = bwdist(b); % Compute distance from zeros to nearest non-zero, i.e., basin to watershed
    l = watershed(d); % MATLAB's built-in watershed; zeros in l are watershed lines
    w = l == 0; 
    g = double(B) .* double(l); 

    % Get min and max grayscale values as double
    min_gray = double(min(f(:))); 
    max_gray = double(max(f(:))); 

    % Generate pseudocolor image using colormap
    colormap_name = 'jet';  % Can choose other colormaps like 'jet', 'hot', 'parula', etc.
    cmap = colormap(colormap_name);
    
    % Map grayscale to RGB color space
    num_colors = size(cmap, 1); 
    gray_range = linspace(min_gray, max_gray, num_colors); 

    % Get grayscale value of each pixel
    f_gray = double(f);

    % Find closest grayscale index for each pixel
    [~, idx] = arrayfun(@(x) find(abs(gray_range - x) == min(abs(gray_range - x))), f_gray, 'UniformOutput', false);

    % Avoid empty outputs, fill missing values
    idx = cellfun(@(x) x(1), idx, 'UniformOutput', true);  

    % Reconstruct RGB image
    RGB_map = cmap(idx, :); 
    RGB_map = reshape(RGB_map, [size(f, 1), size(f, 2), 3]); 

    % Ensure output folder exists
    if ~exist(output_folder, 'dir')
        mkdir(output_folder); 
        disp(['Created output folder: ', output_folder]);
    end

    % Generate save path
    [~, name, ~] = fileparts(image_files(k).name); 
    output_path = fullfile(output_folder, [name, '_colormap.png']);  

    % Save processed image to specified output folder
    imwrite(RGB_map, output_path);

    fprintf('Saved colormap image: %s\n', output_path);
end