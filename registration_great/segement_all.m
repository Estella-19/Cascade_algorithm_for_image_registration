% version 1.0 --Nov/2024
% version 2.0 --Jan/2025

% written by ma200 (wing202506@163.com)


clear, clc;
input_folder = "path_to_your_files";  
output_folder = fullfile(getenv('USERPROFILE'), 'Desktop', 'ProcessedImagestt');  

% Create output folder if it doesn't exist
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

% Get all image files in the folder
image_files = dir(fullfile(input_folder, '*.png')); 

% Process each image
for k = 1:length(image_files)
    filename = fullfile(input_folder, image_files(k).name);
    image = imread(filename);
    
    % Display original image 
    % figure;
    % imshow(image);
    % title('Original Image');

    % Extract color channels
    redChannel = image(:,:,1);
    greenChannel = image(:,:,2);
    blueChannel = image(:,:,3);

    % Create mask for red regions
    mask = (redChannel > greenChannel) & (redChannel > blueChannel);

    % Apply mask to segment red regions
    segmentedRedBlock = image .* uint8(mask);

    % Display segmented red regions 
    % figure;
    % imshow(segmentedRedBlock);
    % title('Segmented Red Block');

    % Create binary mask for non-zero parts in segmented red regions
    redMask = segmentedRedBlock(:,:,1) > 0 | segmentedRedBlock(:,:,2) > 0 | segmentedRedBlock(:,:,3) > 0;

    % Find largest connected regions in each channel
    largestRegionR = getLargestRegion(redChannel > 0 & redMask);
    largestRegionG = getLargestRegion(greenChannel > 0 & redMask);
    largestRegionB = getLargestRegion(blueChannel > 0 & redMask);

    % Create output image
    outputImage = zeros(size(image), 'uint8');

    % Apply largest region masks to respective channels
    outputImage(:,:,1) = uint8(largestRegionR) .* redChannel;
    outputImage(:,:,2) = uint8(largestRegionG) .* greenChannel;
    outputImage(:,:,3) = uint8(largestRegionB) .* blueChannel;

    % Display final composite image
    % figure;
    % imshow(outputImage);
    % title('Largest Regions from R, G, B Channels');

    % Generate save path with original filename + "_processed" suffix
    [~, name, ~] = fileparts(image_files(k).name);  % Get filename without extension
    output_filename = fullfile(output_folder, [name, '_processed.png']); 
    
    imwrite(outputImage, output_filename);

    fprintf('Saved processed image: %s\n', output_filename);
end

% Function to get the largest connected region
function largestRegion = getLargestRegion(mask)
    % Label connected components
    CC = bwconncomp(mask);
    if numel(CC.PixelIdxList) == 0
        largestRegion = false(size(mask)); 
        return;
    end
    % Find largest connected region
    sizes = cellfun(@numel, CC.PixelIdxList);
    [~, idx] = max(sizes);
    
    % Create mask for largest region
    largestRegion = false(size(mask));
    largestRegion(CC.PixelIdxList{idx}) = true;
end