# Nail segmentation checkpoint

Source: https://github.com/austingg/finger-nail-seg
File: https://raw.githubusercontent.com/austingg/finger-nail-seg/main/models/nail-seg.onnx
Downloaded: 2026-10-28
SHA256: 3d235feeef3e4d297ff1e5fc8617ef1eea4ddaaa86cb591c87065a8eed02ed3a
Repository license: GPL-3.0, copied verbatim in nail-seg.LICENSE.
Model described upstream as YOLOv8s-seg, ONNX CPU, input 768 x 768.
Outputs verified locally: (1,37,12096), (1,32,192,192).

The binary checkpoint is unmodified. No claim of accuracy on this project's
users is made. The source repository does not provide an independently verified
training-data provenance/model evaluation report. Review its license and model
provenance before redistributing the checkpoint as part of a released product.
Inference uses OpenCV DNN, with local preprocessing and postprocessing in nail_model.py.

Test photo tests/hand_example.jpg is from examples/input/1.jpg of the same repository,
under its repository license. It is a smoke-test fixture, not independent validation data.
