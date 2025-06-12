% version 1.0 --Nov/2024

% written by ma200 (3244613451@qq.com)


clc;
input_folder = "path_to_your_files"; 

% Define output file path
output_file = fullfile(getenv('USERPROFILE'), 'Desktop', 'Dice_results.txt'); 

% Get all PNG images in the folder
image_files = dir(fullfile(input_folder, '*.png')); 

% Check if images exist
if isempty(image_files)
    error('No PNG images found in input folder.');
end

% Natural sorting by filename (numeric order)
extractNumber = @(name) str2double(regexp(name, '\d+', 'match', 'once'));
[~, index] = sort(cellfun(extractNumber, {image_files.name}));
image_files = image_files(index);

% Read first image as reference
standard_image = imread(fullfile(input_folder, image_files(1).name));

% Ensure grayscale conversion
if size(standard_image, 3) == 3
    standard_image = rgb2gray(standard_image);
end

% Binarize reference image (non-zero pixels as foreground)
standard_image = standard_image > 0;

% Upsample reference image to 300% size
standard_image = imresize(double(standard_image), 3, 'nearest'); 
standard_image = standard_image > 0; 

fid = fopen(output_file, 'w');
if fid == -1
    error('Failed to create output file.');
end

% Write file header
fprintf(fid, 'Image Filename\tDice Coefficient\n');

% Process all images (including self-comparison)
for i = 1:length(image_files)
    current_image = imread(fullfile(input_folder, image_files(i).name));
    
    % Ensure grayscale conversion
    if size(current_image, 3) == 3
        current_image = rgb2gray(current_image);
    end
    
    % Binarize current image
    current_image = current_image > 0;
    
    % Upsample current image to 300% size
    current_image = imresize(double(current_image), 3, 'nearest');
    current_image = current_image > 0;
    
    % Ensure dimension consistency
    [rows, cols] = size(standard_image);
    current_image = imresize(current_image, [rows, cols], 'nearest');
    
    % Calculate Dice coefficient
    intersection = standard_image & current_image;
    dice = 2 * sum(intersection(:)) / (sum(standard_image(:)) + sum(current_image(:)));
    
    fprintf(fid, '%s\t%.6f\n', image_files(i).name, dice);
    fprintf('Processed: %s, Dice = %.6f\n', image_files(i).name, dice);
end

fclose(fid);

% Completion message
disp('Processing complete. Dice results saved to desktop file.');