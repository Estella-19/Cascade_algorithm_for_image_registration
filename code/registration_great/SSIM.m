% version 1.0 --Jan/2025

% written by ma200 (3244613451@qq.com)


% Define folder path
folderPath = "path_to_your_files"; 

% Get all image files in folder
imageFiles = [dir(fullfile(folderPath, '*.jpg')); 
             dir(fullfile(folderPath, '*.png'));
             dir(fullfile(folderPath, '*.tif'))];

% Natural sorting function 
extractNumber = @(name) str2double(regexp(name, '\d+', 'match', 'once'));
[~, index] = sort(cellfun(extractNumber, {imageFiles.name}));
imageFiles = imageFiles(index);

% Check if image files exist
if isempty(imageFiles)
    error('No image files found! Please check the path.');
end

% Disable all warnings
warning('off', 'all');

% Read and preprocess reference image
refImage = imread(fullfile(folderPath, imageFiles(1).name));
if size(refImage, 3) == 3
    refImage = rgb2gray(refImage);
end
refSize = size(refImage); 

% Initialize result storage 
ssimResults = table('Size', [length(imageFiles), 2], ...
    'VariableTypes', {'string', 'double'}, ...
    'VariableNames', {'ImageName', 'SSIM'});

% Calculate SSIM for all images
for i = 1:length(imageFiles)
    try
        currentImage = imread(fullfile(folderPath, imageFiles(i).name));
        
        % Convert to grayscale
        if size(currentImage, 3) == 3
            currentImage = rgb2gray(currentImage);
        end
        
        % Unify image dimensions 
        if ~isequal(size(currentImage), refSize)
            currentImage = imresize(currentImage, refSize);
        end
        
        % Calculate SSIM 
        [ssimVal, ~] = ssim(currentImage, refImage);
        
        ssimResults.ImageName(i) = imageFiles(i).name;
        ssimResults.SSIM(i) = ssimVal;
        
        % Console output
        fprintf('Image: %-30s \t SSIM = %.6f\n', ...
            imageFiles(i).name, ssimVal);
    catch ME
        % Error handling
        fprintf('[Error] File: %-30s \t Reason: %s\n', ...
            imageFiles(i).name, ME.message);
        ssimResults.ImageName(i) = imageFiles(i).name;
        ssimResults.SSIM(i) = NaN;  
    end
end

% Restore warnings
warning('on', 'all');

outputFilename = 'SSIM_Results.xlsx';
writetable(ssimResults, outputFilename, 'Sheet', 1, 'Range', 'A1');
fprintf('\nProcessing complete! Results saved to: %s\n', outputFilename);

% Display reference image self-check
fprintf('\n[Reference Self-Check] %s SSIM = %.6f\n', ...
    imageFiles(1).name, ssimResults.SSIM(1));