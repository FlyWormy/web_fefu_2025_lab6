# docker/django/Dockerfile
# Build stage
FROM python:3.11 as builder

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Создание рабочей директории
WORKDIR /app

# Копирование и установка зависимостей
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копирование всего кода
COPY . .

# Сборка статических файлов
RUN python manage.py collectstatic --noinput

# Production stage
FROM python:3.11-slim

# Установка системных зависимостей для runtime
RUN apt-get update && apt-get install -y \
    libpq-dev \
    curl \
    netcat \
    && rm -rf /var/lib/apt/lists/*

# Создание непривилегированного пользователя
RUN useradd -m -u 1000 django && \
    mkdir -p /app/static /app/media && \
    chown -R django:django /app

# Копирование из builder
COPY --from=builder --chown=django:django /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder --chown=django:django /app /app

# Копирование entrypoint скрипта
COPY docker/django/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /app

USER django

# HEALTHCHECK
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/ || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["gunicorn", "dvfukt.wsgi:application", "--bind", "0.0.0.0:8000"]