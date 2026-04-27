FROM python:3.12-slim
WORKDIR /app
RUN pip install --no-cache-dir openpyxl "psycopg[binary]>=3.1"
COPY ingest.py .
