# -*- coding: utf-8 -*-
"""
Created on Wed Apr 16 21:00:27 2025

@author: ma200
"""
import pydicom
from pydicom.pixel_data_handlers.util import apply_voi_lut
import os
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.widgets import RectangleSelector
from PIL import Image
import tkinter as tk
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg


def load_dicom_sorted(folder_path):
    """Load and sort DICOM files"""
    dicom_files = []
    for root, _, files in os.walk(folder_path):
        for file in files:
            file_path = os.path.join(root, file)
            try:
                ds = pydicom.dcmread(file_path, force=True)
                ds.file_path = file_path  
                if 'PixelData' in ds:
                    dicom_files.append(ds)
            except:
                continue

    # Sort by InstanceNumber
    try:
        dicom_files.sort(key=lambda x: x.InstanceNumber)
    except:
        dicom_files.sort(key=lambda x: x.file_path)
    return dicom_files


def select_roi(image_array):
    """Select a rectangular ROI (displayed at 500% magnification)"""
    scale_factor = 10  

    # Convert the original image to a PIL image
    img_pil = Image.fromarray(image_array)
    enlarged_pil = img_pil.resize(
        (img_pil.width * scale_factor, img_pil.height * scale_factor),
        Image.Resampling.LANCZOS  
    )
    enlarged_array = np.array(enlarged_pil)  

    root = tk.Tk()
    root.title("Draw ROI on Enlarged Image (500%) - Press Enter to Confirm")

    fig, ax = plt.subplots(figsize=(10, 10)) 
    ax.imshow(enlarged_array, cmap='gray')
    ax.set_title("Use mouse to draw rectangle, press Enter when done")

    roi_coords = {'start': None, 'end': None}

    def on_select(eclick, erelease):
        """Coordinate conversion: Convert the pixel coordinates of the enlarged image to the original image coordinates"""
        x1 = int(eclick.xdata / scale_factor)
        y1 = int(eclick.ydata / scale_factor)
        x2 = int(erelease.xdata / scale_factor)
        y2 = int(erelease.ydata / scale_factor)
        roi_coords['start'] = (x1, y1)
        roi_coords['end'] = (x2, y2)

    def on_key(event):
        if event.key == 'enter':
            root.destroy()

    # Reduce the minimum selection size
    rs = RectangleSelector(
        ax, on_select,
        useblit=True,
        button=[1],
        minspanx=1,
        minspany=1,
        spancoords='pixels',
        interactive=True
    )

    fig.canvas.mpl_connect('key_press_event', on_key)

    canvas = FigureCanvasTkAgg(fig, master=root)
    canvas.draw()
    canvas.get_tk_widget().pack()

    root.mainloop()

    if roi_coords['start'] and roi_coords['end']:
        # Sort the coordinates 
        x = sorted([roi_coords['start'][0], roi_coords['end'][0]])
        y = sorted([roi_coords['start'][1], roi_coords['end'][1]])
        return (x[0], y[0], x[1], y[1])
    return None


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

    # Select ROI
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

            if img.dtype != np.uint8:
                img = ((img - img.min()) /
                       (img.max() - img.min()) * 255).astype(np.uint8)

            # Crop the image 
            cropped = img[y_start:y_end, x_start:x_end]

            # Resize to 300x300 
            cropped_image = Image.fromarray(cropped)
            resized_image = cropped_image.resize((300, 300), Image.Resampling.LANCZOS)  # Use high-quality interpolation

            # Save as PNG
            output_path = os.path.join(output_dir, f"crop_{idx + 1:04d}.png")
            resized_image.save(output_path)
        except Exception as e:
            print(f"Error processing {ds.file_path}: {str(e)}")

    print(f"Successfully saved {len(dicom_files)} crops to {output_dir}")


if __name__ == "__main__":
    input_folder = ""
    if not os.path.isdir(input_folder):
        print(f"Error: {input_folder} is not a valid directory")
    else:
        try:
            import matplotlib
            matplotlib.use('TkAgg')  # Explicitly specify to use the TkAgg backend
            process_dicom(input_folder)
        except Exception as e:
            print(f"Error: {str(e)}")