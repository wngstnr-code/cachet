# Cachet Originality Engine (A1) — image produksi.
#
# Default: deps INTI saja + embedder fake (kecil, cepat, tier pHash yang dijamin
# tetap valid). Untuk embedding CLIP nyata (advisory): build dengan
#   docker build --build-arg WITH_ML=1 -t cachet-engine .
# dan set ENGINE_EMBEDDER=clip saat run (image jauh lebih besar, py3.12 dukung ML).
FROM python:3.12-slim

WORKDIR /app

# libjpeg/zlib untuk Pillow (base slim tak menyertakannya).
RUN apt-get update && apt-get install -y --no-install-recommends \
      libjpeg62-turbo zlib1g \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt requirements-ml.txt ./
RUN pip install --no-cache-dir -r requirements.txt

ARG WITH_ML=0
RUN if [ "$WITH_ML" = "1" ]; then pip install --no-cache-dir -r requirements-ml.txt; fi

COPY app ./app

ENV ENGINE_PORT=8100 \
    INDEX_PATH=/data/index \
    ENGINE_EMBEDDER=fake
EXPOSE 8100
VOLUME ["/data"]

CMD ["python", "-m", "uvicorn", "app.main:create_app", "--factory", "--host", "0.0.0.0", "--port", "8100"]
