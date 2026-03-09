FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY src/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ .

# Create output directory
RUN mkdir -p /data/output

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV OUTPUT_DIR=/data/output

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run the application
CMD ["uvicorn", "webhook_handler:app", "--host", "0.0.0.0", "--port", "8080"]
