import requests

YOLO_URL = "http://yolo:8001/detect"

def detect_product(image_bytes):
    response = requests.post(
        YOLO_URL,
        files={"file": image_bytes}
    )
    return response.json()
