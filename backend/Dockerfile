FROM python:3.12-slim
WORKDIR /app
RUN pip install --no-cache-dir \
    "fastapi>=0.111" \
    "uvicorn[standard]>=0.29" \
    "psycopg[binary]>=3.1" \
    "psycopg-pool>=3.2" \
    "pydantic>=2.7"
COPY src ./src
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
