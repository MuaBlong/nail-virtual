"""Prepare the public sample for a local Flutter rendering check."""
import json
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from fastapi import UploadFile
from app import detect_hand

source = Path(__file__).with_name('hand_example.jpg')
target = Path(__file__).resolve().parents[2] / 'flutter_app' / 'build' / 'visual_qa' / 'detection.json'
target.parent.mkdir(parents=True, exist_ok=True)
with source.open('rb') as stream:
    response = detect_hand(UploadFile(filename=source.name, file=stream))
target.write_text(json.dumps(response), encoding='utf-8')
print('Prepared public sample: ' + str(target))
