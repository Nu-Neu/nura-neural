FROM python:3.11-slim

RUN pip install --no-cache-dir readability-lxml requests beautifulsoup4 lxml flask gunicorn

WORKDIR /app
COPY app.py /app/app.py

EXPOSE 8080
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]
