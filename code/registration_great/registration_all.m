% version 1.0 --Nov/2024
% version 2.0 --Jan/2025

% written by ma200 (3244613451@qq.com)


% Specify folder paths
input_folder = "path_to_your_files";  
output_folder = "path_to_your_files";  
gray_output_folder = "path_to_your_files"; 

% Check if output folders exist; create if not
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end
if ~exist(gray_output_folder, 'dir')
    mkdir(gray_output_folder);
end

% Read reference image (png2)
png2 = imread("path_to_your_png");

% Get all image files in input folder
image_files = dir(fullfile(input_folder, '*.png'));  

% Process each image file
for k = 1:length(image_files)
    png1 = imread(fullfile(input_folder, image_files(k).name));
    
    % Apply median filtering to each channel
    filtered_png1 = zeros(size(png1), 'uint16');
    for channel = 1:3
        filtered_png1(:,:,channel) = medfilt2(png1(:,:,channel), [5 5]); 
    end

    % Extract tumor region (template localization)
    non_zero_mask_1 = (filtered_png1(:,:,1) > 0) | (filtered_png1(:,:,2) > 0) | (filtered_png1(:,:,3) > 0);

    % Extract red region from png2
    red_channel_2 = png2(:,:,1); 
    green_channel_2 = png2(:,:,2); 
    blue_channel_2 = png2(:,:,3); 
    red_mask_2 = (red_channel_2 > 10) & (green_channel_2 < 100) & (blue_channel_2 < 100);

    combined_mask_1 = non_zero_mask_1 & true(size(filtered_png1, 1), size(filtered_png1, 2));
    combined_mask_2 = red_mask_2 & true(size(png2, 1), size(png2, 2));

    % Extract non-zero region from png1 (template)
    sub_1 = uint8(zeros(size(filtered_png1))); 
    sub_1(repmat(combined_mask_1, [1, 1, 3])) = filtered_png1(repmat(combined_mask_1, [1, 1, 3]));

    % Calculate normalized cross-correlation (NCC)
    red_channel_png2 = png2(:,:,1);  

    % Ensure template dimensions <= target image dimensions
    template = sub_1;
    if size(template, 1) > size(red_channel_png2, 1) || size(template, 2) > size(red_channel_png2, 2)
        template = imresize(template, [min(size(template, 1), size(red_channel_png2, 1)), ...
                                        min(size(template, 2), size(red_channel_png2, 2))]);
    end

    % Verify template size after resizing
    if size(template, 1) > size(red_channel_png2, 1) || size(template, 2) > size(red_channel_png2, 2)
        error('Template size is still larger than the target image after resizing.');
    end

    % Compute NCC using red channel
    C = normxcorr2(template(:,:,1), red_channel_png2);  
    [max_C, imax] = max(abs(C(:)));
    [ypeak, xpeak] = ind2sub(size(C), imax(1));

    % Calculate offset
    corr_offset = [(xpeak - size(template, 2)), (ypeak - size(template, 1))];

    % Display NCC value
    NCC_value = max_C;
    disp(['Normalized cross-correlation (NCC) value for image ', image_files(k).name, ': ', num2str(NCC_value)]);

    % Calculate matched position
    xoffset = corr_offset(1);
    yoffset = corr_offset(2);
    xbegin = round(xoffset + 1);
    xend = xbegin + size(template, 2) - 1;
    ybegin = round(yoffset + 1);
    yend = ybegin + size(template, 1) - 1;

    % Ensure coordinates are within bounds
    xbegin = max(1, xbegin);
    xend = min(size(png2, 2), xend);
    ybegin = max(1, ybegin);
    yend = min(size(png2, 1), yend);

    % Resize template to match region
    resized_template = imresize(template, [yend - ybegin + 1, xend - xbegin + 1]);

    % Extract overlap region from png2
    overlap_region = png2(ybegin:yend, xbegin:xend, :);

    % Calculate overlap ratio
    template_area = sum(template(:) > 0); 
    overlap_area = sum(resized_template(:) > 0 & overlap_region(:) > 0); 

    overlap_ratio = overlap_area / template_area;  
    overlap_percentage = min(overlap_ratio * 100, 100); 

    % Reduce red channel intensity in png2
    png2_reduced = png2;
    png2_reduced(:,:,1) = png2_reduced(:,:,1) * 0.5; 

    % Overlay template onto png2
    overlay_image = png2_reduced;
    for i = 1:size(resized_template, 1)
        for j = 1:size(resized_template, 2)
            if i <= size(overlay_image, 1) && j <= size(overlay_image, 2)
                overlay_image(ybegin + i - 1, xbegin + j - 1, 1) = resized_template(i, j, 1); 
                overlay_image(ybegin + i - 1, xbegin + j - 1, 2:3) = max(overlay_image(ybegin + i - 1, xbegin + j - 1, 2:3), resized_template(i, j, 2:3));  
            end
        end
    end

    % Enhance red channel contrast
    overlay_image(:,:,1) = imadjust(overlay_image(:,:,1));  

    % Save overlay result
    output_image_name = fullfile(output_folder, ['overlay_' image_files(k).name]);
    imwrite(overlay_image, output_image_name);

    % Convert to grayscale (weighted average)
    gray_image = 0.64 * double(overlay_image(:,:,1)) + 0.31 * double(overlay_image(:,:,2)) + 0.07 * double(overlay_image(:,:,3));

    % Save grayscale image
    gray_output_image_name = fullfile(gray_output_folder, ['gray_' image_files(k).name]);
    imwrite(uint8(gray_image), gray_output_image_name);
end