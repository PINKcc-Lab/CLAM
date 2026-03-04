import h5py
import numpy as np
import matplotlib.pyplot as plt
import argparse
import os
from tqdm import tqdm

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Reconstruct CLAM Probability Map")
    parser.add_argument("--source", type=str, required=True, help="Path to CLAM .h5 result")
    parser.add_argument("--patch_size", type=int, default=256, help="Patch size used in patching")
    args = parser.parse_args()


    files = []

    # --- 1. Load Data ---
    for root, dirs, files in os.walk(args.source):
        for f in files:
            if f.endswith("_0.5_roi_False.h5"):
                files.append(os.path.join(root, f))

    print(f"Found {len(files)} CLAM result files to process.")
    for h5_path in tqdm(files, desc="Processing CLAM results"):
        print(f"Processing file: {h5_path}")
        with h5py.File(h5_path, 'r') as f_o:
            coords = f_o['coords'][:]
            attention_scores = f_o['attention_scores'][:].flatten()

        print("Coordinates shape:", coords.shape)
        print("Attention scores shape:", attention_scores.shape)

        # --- 2. Calculate Grid Dimensions ---
        # We divide by 256 to turn pixel coordinates into "grid indices"
        PATCH_SIZE = 256
        x_indices = coords[:, 0] // PATCH_SIZE
        y_indices = coords[:, 1] // PATCH_SIZE

        # Find the maximum bounds for our map
        grid_w = x_indices.max() + 1
        grid_h = y_indices.max() + 1

        print(f"Grid dimensions: {grid_w} x {grid_h}")

        # --- 3. Create the Probability Map ---
        # Initialize with zeros (or NaN if you want to distinguish between "No tissue" and "Low prob")
        prob_map = np.zeros((grid_h, grid_w))

        # Fill the map with the scores
        # Each (x, y) becomes a pixel in our map
        for i in range(len(coords)):
            prob_map[y_indices[i], x_indices[i]] = attention_scores[i]

        # --- 4. Post-processing (Optional but recommended) ---
        # Since raw attention scores can be tiny, we often normalize to 0-1 for visualization
        if prob_map.max() > 0:
            prob_map_norm = (prob_map - prob_map.min()) / (prob_map.max() - prob_map.min())
        else:
            prob_map_norm = prob_map

        # --- 5. Save the Map ---
        # You can save the map as an image or a numpy array
        output_path = h5_path + ".prob_map.npz"
        np.savez_compressed(output_path, prob_map=prob_map_norm)
        print(f"Saved probability map to: {output_path}")