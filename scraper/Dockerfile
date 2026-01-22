# official Playwright Python image
FROM mcr.microsoft.com/playwright/python:v1.41.0-jammy

WORKDIR /app

# install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt


# RUN playwright install chromium

COPY . .

CMD ["python", "main.py"]