# services/api — the own-your-data signup backend. Python stdlib only, so this image is tiny and
# has nothing to `pip install` and nothing extra to keep patched.
FROM python:3.12-alpine

WORKDIR /app
COPY app.py .

ENV DB_PATH=/data/signups.db \
    PORT=8080
EXPOSE 8080
VOLUME ["/data"]

# busybox wget ships in the alpine base; hit the health endpoint so Compose knows we're ready.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD wget -qO- "http://127.0.0.1:${PORT}/api/health" >/dev/null 2>&1 || exit 1

# -u = unbuffered, so logs show up immediately in `docker compose logs`.
CMD ["python", "-u", "app.py"]
