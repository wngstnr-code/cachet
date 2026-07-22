# Cachet Originality Engine (A1) — image produksi non-root.
#
# Default: deps INTI saja + embedder fake (kecil, cepat, tier pHash yang dijamin
# tetap valid). Untuk embedding CLIP nyata (advisory): build dengan
#   docker build --build-arg WITH_ML=1 -t cachet-engine .
# dan set ENGINE_EMBEDDER=clip saat run (image jauh lebih besar, py3.12 dukung ML).
FROM python:3.12-slim-bookworm

ARG WITH_ML=0

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    ENGINE_PORT=8100 \
    INDEX_PATH=/data/index \
    ENGINE_EMBEDDER=fake

WORKDIR /app

# libjpeg/zlib untuk Pillow (base slim tak menyertakannya).
RUN apt-get update && apt-get install -y --no-install-recommends \
      libjpeg62-turbo zlib1g \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt requirements-ml.txt ./
RUN pip install --no-cache-dir -r requirements.txt

RUN if [ "$WITH_ML" = "1" ]; then pip install --no-cache-dir -r requirements-ml.txt; fi

RUN groupadd --gid 10001 cachet \
    && useradd --uid 10001 --gid cachet --shell /usr/sbin/nologin --create-home cachet \
    && mkdir -p /data/index \
    && chown -R cachet:cachet /data /app

COPY --chown=cachet:cachet app ./app

EXPOSE 8100
VOLUME ["/data"]

USER 10001:10001

HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=4 \
  CMD ["python", "-c", "import os,urllib.request; urllib.request.urlopen('http://127.0.0.1:'+os.getenv('ENGINE_PORT','8100')+'/healthz', timeout=3).read()"]

# app.main membaca ENGINE_PORT sendiri, jadi image tetap benar bila port runtime
# perlu diubah tanpa shell interpolation pada CMD.
CMD ["python", "-m", "app.main"]
