"""Local YOLOv8 nail segmentation through OpenCV DNN (no cloud image upload).

Checkpoint provenance/license: models/nail-seg.SOURCE.md and nail-seg.LICENSE.
Pre/postprocessing implemented here; no third-party inference code imported.
"""
import math
from pathlib import Path
from threading import Lock

import cv2
import numpy as np

MODEL = Path(__file__).resolve().parent / 'models' / 'nail-seg.onnx'
_network = None
_lock = Lock()


def smooth_contour(contour):
    """Uniform arc-length sampling prevents a coarse polygon/faceted nail edge."""
    points = contour.reshape(-1, 2).astype(float)
    closed = np.vstack((points, points[0]))
    distances = np.r_[0., np.cumsum(np.linalg.norm(np.diff(closed, axis=0), axis=1))]
    if distances[-1] < 3:
        return points.astype(np.float32)
    positions = np.linspace(0, distances[-1], 80, endpoint=False)
    result = np.column_stack([np.interp(positions, distances, closed[:, axis]) for axis in range(2)])
    for _ in range(3):
        result = (np.roll(result, 1, axis=0) + 2 * result + np.roll(result, -1, axis=0)) / 4
    return result.astype(np.float32)


def detect_nail_instances(rgb):
    """Returns None when weights are absent, otherwise actual model detections."""
    global _network
    if not MODEL.is_file():
        return None
    h, w = rgb.shape[:2]
    scale = min(768 / w, 768 / h)
    rw, rh = round(w * scale), round(h * scale)
    left, top = (768 - rw) // 2, (768 - rh) // 2
    canvas = np.full((768, 768, 3), 114, np.uint8)
    canvas[top:top + rh, left:left + rw] = cv2.resize(rgb, (rw, rh))
    tensor = canvas.transpose(2, 0, 1)[None].astype(np.float32) / 255
    # DNN Net has mutable input/output buffers; serialize requests using it.
    with _lock:
        if _network is None:
            _network = cv2.dnn.readNetFromONNX(str(MODEL))
        _network.setInput(tensor)
        prediction, prototypes = _network.forward(_network.getUnconnectedOutLayersNames())
    rows = prediction[0].T
    proto = prototypes[0]
    classes = rows.shape[1] - 4 - proto.shape[0]
    scores = rows[:, 4:4 + classes].max(axis=1)
    rows = rows[scores >= .35]
    scores = scores[scores >= .35]
    if not len(rows):
        return []
    boxes = rows[:, :4].copy()
    boxes[:, :2] -= boxes[:, 2:] / 2
    selected = cv2.dnn.NMSBoxes(boxes.tolist(), scores.tolist(), .35, .45)
    instances = []
    for index in np.asarray(selected).flatten()[:15]:
        x, y, bw, bh = boxes[index]
        logits = rows[index, 4 + classes:] @ proto.reshape(proto.shape[0], -1)
        probability = (1 / (1 + np.exp(-np.clip(logits, -40, 40)))).reshape(proto.shape[1:])
        probability = cv2.resize(probability, (768, 768))
        gate = np.zeros((768, 768), np.uint8)
        x0, y0 = max(0, math.floor(x)), max(0, math.floor(y))
        x1, y1 = min(768, math.ceil(x + bw)), min(768, math.ceil(y + bh))
        gate[y0:y1, x0:x1] = 1
        probability *= gate
        mask = (cv2.resize(probability[top:top + rh, left:left + rw], (w, h)) > .5).astype(np.uint8)
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if not contours:
            continue
        contour = max(contours, key=cv2.contourArea)
        if cv2.contourArea(contour) < 20:
            continue
        contour = smooth_contour(contour)
        moments = cv2.moments(contour)
        if moments['m00'] == 0:
            continue
        instances.append({'contour': contour, 'score': float(scores[index]),
                          'center': np.array([moments['m10'], moments['m01']]) / moments['m00']})
    return instances


def match_instances(instances, fingers, image_size, *, include_extras=False, hand_points=None):
    """One-to-one globally optimal matching; unmatched fingers are allowed.

    fingers = list of (name, tip_pixels, joint_pixels).
    A missing finger costs 1.25. Geometric gates reject nails on another hand.
    """
    costs = []
    for instance in instances:
        row = []
        for _, tip, joint in fingers:
            tip, joint = np.array(tip), np.array(joint)
            length = np.linalg.norm(tip - joint)
            if length < 8:
                row.append(float('inf'))
                continue
            up = (tip - joint) / length
            right = np.array([-up[1], up[0]])
            delta = instance['center'] - tip
            along, across = -np.dot(delta, up) / length, abs(np.dot(delta, right)) / length
            distance = np.linalg.norm(delta + up * length * .38) / length
            row.append(float(distance) if -.35 < along < 1.15 and across < .65 and distance < 1.0 else float('inf'))
        costs.append(row)
    states = {0: (0., [])}
    for j, row in enumerate(costs):
        updated = dict(states)
        for mask, (cost, pairs) in states.items():
            for i, value in enumerate(row):
                if mask & (1 << i) or not math.isfinite(value):
                    continue
                next_mask = mask | (1 << i)
                next_cost = cost + value
                if next_mask not in updated or next_cost < updated[next_mask][0]:
                    updated[next_mask] = (next_cost, pairs + [(i, j)])
        states = updated
    _, pairs = min(states.items(), key=lambda item: item[1][0] + (len(fingers) - item[0].bit_count()) * 1.25)[1]
    output = {}
    for finger_index, instance_index in pairs:
        name, tip, joint = fingers[finger_index]
        instance = instances[instance_index]
        geometry = _instance_geometry(instance, tip, joint, image_size)
        if geometry is not None:
            output[name] = {**geometry, 'design_index': finger_index}
    if include_extras and pairs:
        assigned = {j for _, j in pairs}
        median_area = np.median([cv2.contourArea(instances[j]['contour'].astype(np.float32)) for j in assigned])
        hull = cv2.convexHull(np.array(hand_points, np.float32)) if hand_points is not None else None
        margin = max(np.ptp(np.array(hand_points), axis=0)) * .2 if hull is not None else 0
        for j, instance in enumerate(instances):
            if j in assigned or instance['score'] < .6:
                continue
            contour = instance['contour'].astype(np.float32)
            area = cv2.contourArea(contour)
            if not .25 * median_area <= area <= 3 * median_area:
                continue
            if hull is not None and cv2.pointPolygonTest(hull, tuple(map(float, instance['center'])), True) < -margin:
                continue
            # Do not interpret a second detection of an existing nail as a sixth nail.
            if any(_overlap_fraction(contour, instances[k]['contour']) > .5 for k in assigned):
                continue
            candidates = []
            for i, (_, tip, joint) in enumerate(fingers):
                up = np.array(tip, float) - np.array(joint, float)
                length = np.linalg.norm(up)
                if length < 8:
                    continue
                up /= length
                delta = instance['center'] - tip
                along = -np.dot(delta, up) / length
                across = abs(np.dot(delta, [-up[1], up[0]])) / length
                if -.5 < along < 1.15 and across < 1.5:
                    candidates.append((np.linalg.norm(delta + up * length * .38) / length, i))
            if not candidates:
                continue
            _, i = min(candidates)
            geometry = _instance_geometry(instance, fingers[i][1], fingers[i][2], image_size)
            if geometry is not None:
                output[f'extra_{len(output) + 1}'] = {**geometry, 'design_index': i, 'extra_nail': True}
                assigned.add(j)
    return output


def _overlap_fraction(first, second):
    a, b = cv2.convexHull(first.astype(np.float32)), cv2.convexHull(second.astype(np.float32))
    intersection, _ = cv2.intersectConvexConvex(a, b)
    return intersection / max(1., min(cv2.contourArea(a), cv2.contourArea(b)))


def _instance_geometry(instance, tip, joint, image_size):
    width, height = image_size
    up = np.array(tip, dtype=float) - np.array(joint, dtype=float)
    length = np.linalg.norm(up)
    if length < 8:
        return None
    up /= length
    contour = instance['contour'].astype(float)
    eigenvalues, eigenvectors = np.linalg.eigh(np.cov(contour.T))
    major = eigenvectors[:, -1]
    if major @ up < 0:
        major = -major
    if eigenvalues[-1] > max(eigenvalues[0], 1.) * 1.25 and major @ up > .5:
        up = major
    right, down = np.array([-up[1], up[0]]), -up
    local = np.column_stack((contour @ right, contour @ down))
    minimum, maximum = local.min(axis=0), local.max(axis=0)
    extent = maximum - minimum
    if np.any(extent < 2):
        return None
    center = (minimum + maximum) / 2
    original_center = center[0] * right + center[1] * down
    return {
        'x': float(original_center[0] / width), 'y': float(original_center[1] / height),
        'width': float(extent[0] / width), 'height': float(extent[1] / height),
        'rotation': math.atan2(float(right[1]), float(right[0])),
        'polygon': ((local - minimum) / extent).tolist(),
        'method': 'nail_model', 'score': instance['score'],
        'needs_review': True, 'visible': True,
    }
