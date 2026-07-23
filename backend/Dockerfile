# Korvexa API image.
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# psycopg2-binary ships wheels, so no build toolchain is needed.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Migrations run on start (see entrypoint), then uvicorn serves the API.
RUN chmod +x ./entrypoint.sh
EXPOSE 8000
ENTRYPOINT ["./entrypoint.sh"]
