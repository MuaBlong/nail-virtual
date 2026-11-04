"""Image-based nail boundary refinement. GrabCut is NOT a trained nail model.

Landmarks propose a search region; image colours determine the boundary.
Ambiguous/low-contrast crops return None, never a fabricated contour.
"""
import math

import cv2
import numpy as np


def segment_nail(rgb, tip, joint):
    tip, joint = np.asarray(tip, dtype=float), np.asarray(joint, dtype=float)
    length = float(np.linalg.norm(tip - joint))
    if length < 12:
        return None
    # Upright local crop: tip above the joint. Bound processing cost per finger.
    up = (tip - joint) / length
    right = np.array([-up[1], up[0]])
    center = tip - up * length * 0.38
    side = 160
    scale = side / (length * 1.8)
    matrix = np.array([
        [right[0] * scale, right[1] * scale, side / 2 - np.dot(right, center) * scale],
        [-up[0] * scale, -up[1] * scale, side / 2 + np.dot(up, center) * scale],
    ])
    crop = cv2.warpAffine(rgb, matrix, (side, side))
    valid = cv2.warpAffine(np.ones(rgb.shape[:2], np.uint8), matrix, (side, side))
    yy, xx = np.mgrid[:side, :side]
    radius = ((xx - 80) / 35) ** 2 + ((yy - 80) / 44) ** 2
    seed = (radius < 0.08) & (valid > 0)
    surrounding = (radius > 1.15) & (radius < 1.8) & (valid > 0)
    if seed.sum() < 30 or surrounding.sum() < 100:
        return None
    lab = cv2.cvtColor(crop, cv2.COLOR_RGB2LAB).astype(float)
    # Reject lack of colour evidence before introducing any forced foreground.
    contrast = float(np.linalg.norm(np.median(lab[seed], axis=0) - np.median(lab[surrounding], axis=0)))
    if contrast < 9:
        return None
    mask = np.full((side, side), cv2.GC_BGD, np.uint8)
    mask[(radius < 1.7) & (valid > 0)] = cv2.GC_PR_BGD
    mask[(radius < 0.8) & (valid > 0)] = cv2.GC_PR_FGD
    mask[seed] = cv2.GC_FGD
    try:
        cv2.grabCut(crop, mask, None, np.zeros((1, 65)), np.zeros((1, 65)), 4, cv2.GC_INIT_WITH_MASK)
    except cv2.error:
        return None
    binary = np.isin(mask, [cv2.GC_FGD, cv2.GC_PR_FGD]).astype(np.uint8)
    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    candidates = [c for c in contours if cv2.pointPolygonTest(c, (80, 80), False) >= 0]
    if not candidates:
        return None
    contour = max(candidates, key=cv2.contourArea)
    area = cv2.contourArea(contour)
    x, y, w, h = cv2.boundingRect(contour)
    if not (450 < area < 6500 and 18 < w < 100 and 22 < h < 120):
        return None
    # A component reaching the search boundary is likely skin/background leakage.
    boundary = contour[:, 0, :]
    if np.max(radius[boundary[:, 1], boundary[:, 0]]) > 1.55:
        return None
    approximation = cv2.approxPolyDP(contour, 1.2, True)[:, 0, :].astype(float)
    inverse = cv2.invertAffineTransform(matrix)
    original = cv2.transform(approximation[None, :, :], inverse)[0]
    image_h, image_w = rgb.shape[:2]
    if np.any(original < 0) or np.any(original[:, 0] >= image_w) or np.any(original[:, 1] >= image_h):
        return None
    # Tight local box gives texture dimensions; polygon coordinates stay local [0,1].
    local_center = np.array([x + (w - 1) / 2, y + (h - 1) / 2])
    original_center = inverse[:, :2] @ local_center + inverse[:, 2]
    polygon = ((approximation - [x, y]) / [max(w - 1, 1), max(h - 1, 1)]).tolist()
    return {
        'x': float(original_center[0] / image_w),
        'y': float(original_center[1] / image_h),
        'width': float((w - 1) / scale / image_w),
        'height': float((h - 1) / scale / image_h),
        'rotation': math.atan2(float(right[1]), float(right[0])),
        'polygon': polygon,
        'method': 'grabcut_candidate',
        'needs_review': True,
    }
