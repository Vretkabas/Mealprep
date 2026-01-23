from fastapi import FastAPI, UploadFile
from ultralytics import YOLO
from PIL import Image
import io

app = FastAPI()

# tijdelijk standaard model
model = YOLO("yolov8n.pt")

@app.post("/detect")
async def detect(file: UploadFile):
    image_bytes = await file.read()
    image = Image.open(io.BytesIO(image_bytes))

    results = model(image)

    detections = []
    for r in results:
        for box in r.boxes:
            detections.append({
                "label": model.names[int(box.cls)],
                "confidence": float(box.conf)
            })

    return {"detections": detections}
