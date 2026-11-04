
import io
import math
import base64
from pathlib import Path

import mediapipe as mp
import numpy as np

from PIL import Image, ImageOps
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from nail_segmentation import segment_nail
from nail_model import detect_nail_instances, match_instances, MODEL as NAIL_MODEL_PATH
from nail_texture import illumination_grid, texture_data_uri, surface_maps

app = FastAPI(title="Nail Virtual AI")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

MODEL_PATH = (
    Path(__file__).resolve().parent
    / "models"
    / "hand_landmarker.task"
)

# Ngón cái, trỏ, giữa, áp út, út.
# Mỗi ngón: đầu ngón và khớp gần đầu ngón.
FINGERS = [
    ("thumb", 4, 3),
    ("index", 8, 7),
    ("middle", 12, 11),
    ("ring", 16, 15),
    ("pinky", 20, 19),
]


@app.get("/")
def home():
    return {
        "success": True,
        "message": "Nail Virtual AI đang hoạt động"
        ,"nail_model_available": NAIL_MODEL_PATH.is_file()
    }


@app.post("/detect-hand")
def detect_hand(file: UploadFile = File(...)):

    # 1. Kiểm tra file mô hình AI
    if not MODEL_PATH.is_file():
        raise HTTPException(
            status_code=500,
            detail="Chưa tìm thấy hand_landmarker.task"
        )

    # 2. Đọc ảnh người dùng gửi lên
    contents = file.file.read(10 * 1024 * 1024 + 1)

    if not contents:
        raise HTTPException(
            status_code=400,
            detail="Ảnh đang trống"
        )

    if len(contents) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail="Ảnh vượt quá 10 MB"
        )

    try:
        picture = Image.open(io.BytesIO(contents))
        if picture.width * picture.height > 24_000_000:
            raise HTTPException(status_code=413, detail="Ảnh vượt quá 24 triệu pixel")
        picture = ImageOps.exif_transpose(picture)
        picture = picture.convert("RGB")
        picture.thumbnail((2048, 2048))
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=400,
            detail="File ảnh không hợp lệ"
        )

    image_width, image_height = picture.size

    # 3. Chuyển ảnh sang MediaPipe
    pixel_data = np.ascontiguousarray(
        np.asarray(picture)
    )

    mp_image = mp.Image(
        image_format=mp.ImageFormat.SRGB,
        data=pixel_data
    )

    # 4. Khởi tạo AI
    options = mp.tasks.vision.HandLandmarkerOptions(
        base_options=mp.tasks.BaseOptions(
            model_asset_path=str(MODEL_PATH)
        ),
        running_mode=mp.tasks.vision.RunningMode.IMAGE,
        num_hands=2,
        min_hand_detection_confidence=0.5,
    )

    try:
        with mp.tasks.vision.HandLandmarker.create_from_options(
            options
        ) as detector:
            result = detector.detect(mp_image)
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Lỗi mô hình AI: {error}"
        )

    # 5. Kiểm tra có phát hiện bàn tay không
    if not result.hand_landmarks:
        return {
            "success": False,
            "message": "Không phát hiện được bàn tay",
            "nails": []
        }

    points = result.hand_landmarks[0]
    if len(result.hand_landmarks) > 1:
        return {"success": False, "message": "Hãy chụp một bàn tay mỗi lần", "nails": []}
    fingers = [(name, (points[t].x * image_width, points[t].y * image_height),
                (points[j].x * image_width, points[j].y * image_height)) for name, t, j in FINGERS]
    try:
        instances = detect_nail_instances(pixel_data)
        matched = match_instances(instances, fingers, picture.size, include_extras=True,
            hand_points=[(p.x * image_width, p.y * image_height) for p in points]) if instances is not None else {}
    except Exception as error:
        raise HTTPException(status_code=503, detail="Không chạy được mô hình nhận diện móng. Hãy kiểm tra AI service.") from error
    if instances is not None and not matched:
        return {"success": False, "message": "Chưa thấy rõ vùng móng. Hãy hướng mu bàn tay về camera, chụp đủ sáng và không che các móng.", "nails": []}
    nails = []

    # 6. Ước lượng vị trí của 5 móng
    for name, tip_id, joint_id in FINGERS:

        tip = points[tip_id]
        joint = points[joint_id]

        tx = tip.x * image_width
        ty = tip.y * image_height

        jx = joint.x * image_width
        jy = joint.y * image_height

        dx = tx - jx
        dy = ty - jy

        length = math.hypot(dx, dy)

        # Tâm móng ước lượng gần đầu ngón
        # Tâm móng nằm gần đầu ngón

        # Tâm móng nằm gần đầu ngón tay
        center_x = tx - 0.40 * dx
        center_y = ty - 0.40 * dy

        # Tự động ước lượng kích thước từng móng
        if name == "thumb":
            nail_width = length * 1.05
            nail_height = length * 1.15
        elif name == "pinky":
            nail_width = length * 0.82
            nail_height = length * 1.10
        else:
            nail_width = length * 0.88
            nail_height = length * 1.12

        # Góc xoay theo hướng ngón tay
        rotation = math.atan2(dy, dx) + math.pi / 2


        nail = {
            "finger": name,
            "x": max(0.0, min(1.0, center_x / image_width)),
            "y": max(0.0, min(1.0, center_y / image_height)),
            "width": nail_width / image_width,
            "height": nail_height / image_height,
            "rotation": rotation,
            "method": "landmark_estimate",
            "needs_review": True,
            "visible": instances is None,
        }
        refined = matched.get(name) if instances is not None else segment_nail(pixel_data, (tx, ty), (jx, jy))
        if refined is not None:
            nail.update(refined)
            nail['shading'] = illumination_grid(pixel_data, nail)
            nail['surface'] = surface_maps(pixel_data, nail)
        nails.append(nail)

    # Keep distinct additional nail regions; MediaPipe itself has only five finger labels.
    for name, geometry in matched.items():
        if not geometry.get('extra_nail'):
            continue
        nail = {'finger': name, **geometry}
        nail['shading'] = illumination_grid(pixel_data, nail)
        nail['surface'] = surface_maps(pixel_data, nail)
        nails.append(nail)

    # 7. Trả kết quả cho Flutter
    normalized = io.BytesIO()
    picture.save(normalized, format="PNG")
    segmented = sum(nail["method"] in ("grabcut_candidate", "nail_model") for nail in nails)
    return {
        "success": True,
        "message": "Nhận diện bàn tay thành công",
        "image_width": image_width,
        "image_height": image_height,
        "nails": nails,
        "normalized_image": base64.b64encode(normalized.getvalue()).decode("ascii"),
        "segmented_count": segmented,
        "requires_review": True,
        "warning": (f"Nhận diện được {segmented} vùng móng. " +
                    "Chỉ ghép vào vùng móng nhìn thấy. Hãy kiểm tra kết quả trước khi lưu.") if instances is not None else
                   f"Đang dùng nhận diện dự phòng: {segmented}/5 vùng ứng viên. Các vùng còn lại chỉ được ước lượng; hãy chỉnh tay.",
    }


@app.post('/extract-nail-design')
def extract_nail_design(file: UploadFile = File(...)):
    result = detect_hand(file)
    canonical = [n for n in result.get('nails', []) if n['finger'] in {f[0] for f in FINGERS}]
    if not result.get('success') or len(canonical) != 5 or any(n['method'] != 'nail_model' or not n.get('visible') for n in canonical):
        raise HTTPException(status_code=422, detail='Ảnh mẫu cần có một bàn tay nhìn rõ đủ 5 móng để lấy thiết kế theo từng ngón.')
    rgb = np.asarray(Image.open(io.BytesIO(base64.b64decode(result['normalized_image']))).convert('RGB'))
    return {'success': True, 'designs': {nail['finger']: texture_data_uri(rgb, nail) for nail in canonical}}
