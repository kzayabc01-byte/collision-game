"""Encode a painted reference as four linear-colour pigment weights for Godot.

Authoring utility only; Godot does not run Python. Requires numpy and Pillow.
The alpha channel is lavender weight, never surface transparency.
"""

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


PIGMENTS_SRGB = np.array(
    [[0.13, 0.18, 0.34], [0.70, 0.39, 0.68],
     [0.12, 0.65, 0.65], [0.46, 0.47, 0.81]], dtype=np.float64
)


def linearize(value):
    return np.where(value <= 0.04045, value / 12.92,
                    ((value + 0.055) / 1.055) ** 2.4)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[2]
                        / "assets/ground/dream_ground_weights.png")
    args = parser.parse_args()
    image = Image.open(args.source).convert("RGB")
    rgb = np.asarray(image, dtype=np.float64) / 255.0
    pigments = linearize(PIGMENTS_SRGB)
    matrix = np.vstack([pigments.T, np.ones(4)])
    targets = np.concatenate([linearize(rgb), np.ones((*rgb.shape[:2], 1))], axis=2)
    weights = targets @ np.linalg.inv(matrix).T
    # Keep interpolation convex and stable for future palette edits.
    weights = np.maximum(weights, 0.0)
    weights /= weights.sum(axis=2, keepdims=True)
    encoded = np.rint(weights * 255.0).astype(np.uint8)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(encoded).save(args.output)
    reconstructed = (encoded / 255.0) @ pigments
    error = np.sqrt(np.mean((reconstructed - linearize(rgb)) ** 2))
    print(f"Saved {args.output} ({image.width}x{image.height}); linear RGB RMSE={error:.6f}")


if __name__ == "__main__":
    main()
