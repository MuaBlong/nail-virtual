"""Extract an upright nail texture and its measured local illumination."""
import base64
import io
import math

import cv2
import numpy as np
from PIL import Image


def extract_texture(rgb, nail):
    h, w = rgb.shape[:2]
    theta = nail['rotation']
    right = np.array([math.cos(theta), math.sin(theta)])
    down = np.array([-math.sin(theta), math.cos(theta)])
    center = np.array([nail['x'] * w, nail['y'] * h])
    nw, nh = max(2, round(nail['width'] * w)), max(2, round(nail['height'] * h))
    matrix = np.array([[*right, nw / 2 - right @ center],
                       [*down, nh / 2 - down @ center]])
    crop = cv2.warpAffine(rgb, matrix, (nw, nh), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
    mask = np.zeros((nh, nw), np.uint8)
    points = np.rint(np.array(nail['polygon']) * [nw - 1, nh - 1]).astype(np.int32)
    cv2.fillPoly(mask, [points], 255)
    return crop, mask


def illumination_grid(rgb, nail):
    crop, mask = extract_texture(rgb, nail)
    light = cv2.cvtColor(crop, cv2.COLOR_RGB2GRAY).astype(np.float32)
    mean = max(float(light[mask > 0].mean()), 30.)
    # Neutral soft-light value is .5; retain illumination, not the old polish colour.
    values = cv2.resize(cv2.GaussianBlur(light, (0, 0), 1), (8, 16))
    return np.clip(.5 + (values - mean) / mean * .4, .25, .75).flatten().round(3).tolist()


def texture_data_uri(rgb, nail):
    crop, mask = extract_texture(rgb, nail)
    alpha = cv2.GaussianBlur(mask, (3, 3), .5)
    rgba = np.dstack((crop, alpha))
    buffer = io.BytesIO()
    Image.fromarray(rgba).save(buffer, format='PNG')
    return 'data:image/png;base64,' + base64.b64encode(buffer.getvalue()).decode('ascii')


def _png_uri(pixels):
    buffer = io.BytesIO()
    Image.fromarray(pixels).save(buffer, format='PNG')
    return 'data:image/png;base64,' + base64.b64encode(buffer.getvalue()).decode('ascii')


def surface_maps(rgb, nail):
    """Measured illumination/reflections and an inward feathered coverage mask.

    Smooth only pixels belonging to the nail (normalized convolution), otherwise
    skin/background near the outline would contaminate the surface lighting.
    Original RGB pigment is never returned as the illumination texture.
    """
    crop, mask = extract_texture(rgb, nail)
    valid = (mask > 0).astype(np.float32)
    light = cv2.cvtColor(crop, cv2.COLOR_RGB2GRAY).astype(np.float32)
    values = light[valid > 0]
    mean = max(float(np.median(values)), 25.)
    sigma = max(1.2, min(crop.shape[:2]) * .09)
    weights = cv2.GaussianBlur(valid, (0, 0), sigma)
    smooth = cv2.GaussianBlur(light * valid, (0, 0), sigma) / np.maximum(weights, 1e-4)
    smooth[valid == 0] = mean
    # Low-frequency shape, with a small bounded amount of real surface texture.
    fine = np.clip(light - cv2.GaussianBlur(light, (0, 0), .9), -4., 4.)
    illumination = np.clip(.5 + (smooth - mean) / mean * .42 + fine / 255 * .35, .28, .72)
    illumination[valid == 0] = .5
    illumination = cv2.resize(illumination, (64, 96), interpolation=cv2.INTER_LINEAR)
    illumination = np.rint(illumination * 255).astype(np.uint8)

    # Preserve observed bright reflections, rather than drawing the same white
    # stripe on every finger. Conservative strength limits old painted motifs.
    brightness_gate = np.clip((light - max(165., float(np.percentile(values, 60)))) / 40., 0, 1)
    local_peaks = np.clip((light - smooth - 7.) / 45., 0, 1)
    broad_reflection = np.clip((light - mean) / 40., 0, 1)
    peaks = np.maximum(local_peaks, broad_reflection * .8) * brightness_gate * valid
    peaks = cv2.GaussianBlur(peaks, (0, 0), .7)
    peaks = np.clip(cv2.resize(peaks, (64, 96)), 0, 1)
    specular = np.full((96, 64, 4), 255, np.uint8)
    specular[:, :, 3] = np.rint(peaks * 255).astype(np.uint8)

    # Feather inward, so the applied colour cannot grow outside the detected nail.
    padded = np.pad((mask > 0).astype(np.uint8), 2)
    distance = cv2.distanceTransform(padded, cv2.DIST_L2, 5)[2:-2, 2:-2]
    feather = max(1.2, min(2., min(mask.shape) * .025))
    alpha = np.clip((distance - .25) / feather, 0, 1) * valid
    alpha = cv2.resize(alpha, (64, 96), interpolation=cv2.INTER_LINEAR)
    coverage = np.full((96, 64, 4), 255, np.uint8)
    coverage[:, :, 3] = np.rint(alpha * 255).astype(np.uint8)
    # Infer only a small illumination cast from near-neutral bright reflections.
    # Saturated old polish must not recolour the selected design.
    neutral = (np.ptp(crop.astype(float), axis=2) < 30) & (light > 180) & (valid > 0)
    tint = np.ones(3)
    if np.count_nonzero(neutral) >= 8:
        reflected = np.median(crop[neutral], axis=0)
        tint = np.clip(reflected / max(float(reflected.mean()), 1.), .94, 1.06)
    return {'lighting': _png_uri(illumination), 'highlights': _png_uri(specular),
            'coverage': _png_uri(coverage), 'tint': tint.round(4).tolist()}
