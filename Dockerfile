# Stage 1: Builder
FROM python:3.11-slim AS builder

WORKDIR /app

# Install build dependencies (if needed for compiling wheels)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /root/.local /root/.local

# Update PATH so Python can find installed packages
ENV PATH=/root/.local/bin:$PATH

# Copy application code
COPY . .

# Expose Flask port
EXPOSE 5000

# Run with Gunicorn for production
CMD ["gunicorn", "-b", "0.0.0.0:5000", "app:app"]
