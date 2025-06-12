[toc]

# 1.Introduction

**Software Version**：
MATLAB R2022a
Spyder(Python 3.11)

----------------------
**File Structure**
**For initial segmentation**：
**`dicom_png_segement.py`**
 **Registration**:
 **`colormap-all.m`** : watershed-based pseudo-color enhancement
 **`segement_all.m`** : connected component separation
 **`Bspline-all.m`** : B-spline deformation
 **`registration-all.m`** : maximization of the normalized cross-correlation coefficient
 **Conduct metric testing**:
 **`Dice.m`**
 **`SSIM.m`**
 
 ----------------------

# 2.About the code
## 2.1 Functional code
### 2.1.1 dicom_png_segement.py
It is used to convert DICOM images into PNG images and preliminarily segment the region of interest, reducing the interference from the remaining parts.

Environment configuration:
```python
import pydicom
from pydicom.pixel_data_handlers.util import apply_voi_lut
import os
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.widgets import RectangleSelector
from PIL import Image
import tkinter as tk
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
```

Some of the core codes are as follows:
```python
def process_dicom(folder_path):
    # Load DICOM files
    dicom_files = load_dicom_sorted(folder_path)
    if not dicom_files:
        raise ValueError("No valid DICOM files found in directory")

    # Process the first image
    first_ds = dicom_files[143]
    first_img = apply_voi_lut(first_ds.pixel_array, first_ds)

    # Normalize to 0-255
    if first_img.dtype != np.uint8:
        first_img = ((first_img - first_img.min()) /
                     (first_img.max() - first_img.min()) * 255).astype(np.uint8)

    # Select ROI (operate on the enlarged image)
    roi = select_roi(first_img)
    if not roi:
        raise ValueError("No ROI selected")

    x_start, y_start, x_end, y_end = roi

    # Create the output directory
    output_dir = os.path.join(os.path.expanduser("~"), "Desktop", "DICOM_Crops")
    os.makedirs(output_dir, exist_ok=True)

    # Process all DICOM files
    for idx, ds in enumerate(dicom_files):
        try:
            img = apply_voi_lut(ds.pixel_array, ds)

            # Normalize the image
            if img.dtype != np.uint8:
                img = ((img - img.min()) /
                       (img.max() - img.min()) * 255).astype(np.uint8)

            # Crop the image (use the original coordinates)
            cropped = img[y_start:y_end, x_start:x_end]

            # Resize to 300x300 (Note: The resize parameter of PIL is (width, height))
            cropped_image = Image.fromarray(cropped)
            resized_image = cropped_image.resize((300, 300), Image.Resampling.LANCZOS)  # Use high-quality interpolation

            # Save as PNG
            output_path = os.path.join(output_dir, f"crop_{idx + 1:04d}.png")
            resized_image.save(output_path)
        except Exception as e:
            print(f"Error processing {ds.file_path}: {str(e)}")

    print(f"Successfully saved {len(dicom_files)} crops to {output_dir}")
```
----
### 2.1.2 colormap-all.m
It is used to perform pseudo-color enhancement on the images, which is beneficial for segmenting the region of interest.
Some of the core codes are as follows:
```matlab
% Watershed algorithm segmentation
B = im2bw(f, graythresh(f)); % Binarize; ensure catchment basins have lower values (0)
b = -B;
d = bwdist(b); % Compute distance from zeros to nearest non-zero, i.e., basin to watershed
l = watershed(d); % MATLAB's built-in watershed; zeros in l are watershed lines
w = l == 0; % Extract edges
g = double(B) .* double(l); % Obtain watershed labels

% Get min and max grayscale values as double
min_gray = double(min(f(:))); % Ensure double type
max_gray = double(max(f(:))); % Ensure double type

% Generate pseudocolor image using colormap
colormap_name = 'jet'; % Can choose other colormaps like 'jet', 'hot', 'parula', etc.
cmap = colormap(colormap_name);

% Map grayscale to RGB color space
num_colors = size(cmap, 1); % Get number of colors in colormap
gray_range = linspace(min_gray, max_gray, num_colors); % Create grayscale value range
```
image for colormap
![image for colormap](/imgs/2025-05-08/nFnKWc7MM1wOlGkM.png)

---
### 2.1.3 segement_all.m
It is used to segment the images after pseudo-color enhancement.
By separating the color channels, we are able to individually screen out all the regions whose colors are similar to those of the region of interest. Moreover, these regions are spatially non-connected and differ in area. In our research object, almost the area of the region of interest is the largest. Each color region can be regarded as a connected domain. By screening out the connected domain with the largest area, we obtain the region of interest. This method has been well-tested on our dataset.
$$ N = \text{count}(C) $$
$$ A = \sum_{(x,y)\in c}1 $$
Some of the core codes are as follows:
```matlab
% Function to get the largest connected region
function largestRegion = getLargestRegion(mask)

% Label connected components
CC = bwconncomp(mask);
if numel(CC.PixelIdxList) == 0
largestRegion = false(size(mask)); % Return empty mask if no regions
return;
end

% Find largest connected region
sizes = cellfun(@numel, CC.PixelIdxList);
[~, idx] = max(sizes);

% Create mask for largest region
largestRegion = false(size(mask));
largestRegion(CC.PixelIdxList{idx}) = true;

end
```
---
### 2.1.4 Bspline-all.m
Based on previous research **(D.Kroon, University of Twente)**, we perform channel-wise deformation on color images and automatically crop the images of the region of interest at different positions to reduce unnecessary distortion during the deformation process.
Some of the core codes are as follows:
```matlab
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
```
---
### 2.1.5 registration-all.m
Given a template image, it registers the images to the template image and provides the NCC (Normalized Cross-Correlation) value.
In this code, by moving the image to be registered, the normalized cross - correlation coefficient between it and the template is calculated to find the position corresponding to the maximum normalized cross - correlation coefficient. By adjusting the size and position of the image, the maximum normalized cross - correlation with the template image is achieved. At this time, we will obtain the registered images of different time phases, and the region of interest will no longer float.
$$ \text{NCC}(I, T)=\frac{\sum_{i=1}^{N}(I_i - \bar{I})(T_i - \bar{T})}{\sqrt{\sum_{i = 1}^{N}(I_i - \bar{I})^2\sum_{i = 1}^{N}(T_i - \bar{T})^2}} $$
Some of the core codes are as follows:
```matlab
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
```
image for NCC

![](/imgs/2025-05-08/VJmmMke3PPHzeD0Y.jpeg)
---

## 2.2 Index test code
### 2.2.1 Dice.m
It is used to compare the images before and after deformation with the template to evaluate the effect of deformation.
By running this piece of code, you can obtain the matching degree between the test image and the template image. It can be clearly seen that the Dice coefficient of the registered image is significantly improved.
$$ Dice = \frac{2|X \cap Y|}{|X| + |Y|} $$
The following is an example table:
|example|before|after|
|---|---|---|
|case1|0.929583|0.956053|
|case2|0.843189|0.890658|
|case3|0.778121|0.931155|

---
### 2.2.2 SSIM.m
It is used to evaluate the structural similarity of the images before and after registration.
$$ SSIM(x,y) = f(l(x,y), c(x,y), s(x,y)) = [l(x,y)]^{\alpha} [c(x,y)]^{\beta} [s(x,y)]^{\gamma} $$
The following is an example table:
|example|before|after|
|---|---|---|
|case1|0.885760|0.957458|
|case2|0.804049|0.955993|
|case3|0.725159|0.948976|
---
# 3 Conclusion
Through the above operations, we successfully registered the region of interest in the floating image to the standard template and achieved good results on the dataset. Our code can be directly obtained on GitHub.

