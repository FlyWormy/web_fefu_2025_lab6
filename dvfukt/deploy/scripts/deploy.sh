#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функции для логирования
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Переменные
PROJECT_NAME="fefu_lab"
PROJECT_DIR="/var/www/${PROJECT_NAME}"
REPO_URL="https://github.com/FlyWormy/web_fefu_2025_lab4.git"
ENV_FILE="/etc/${PROJECT_NAME}.env"

# Проверка прав
if [[ $EUID -ne 0 ]]; then
    log_error "Этот скрипт должен запускаться с правами root!"
    exit 1
fi

log_info "Начинаем деплой проекта ${PROJECT_NAME}..."

# 1. Обновление системы и установка базовых утилит
log_info "Обновление системы и установка базовых утилит..."
apt-get update
apt-get upgrade -y
apt-get install -y curl wget git build-essential

# 2. Установка Python и зависимостей
log_info "Установка Python и зависимостей..."
apt-get install -y python3-pip python3-dev python3-venv

# 3. Установка PostgreSQL
log_info "Установка PostgreSQL..."
apt-get install -y postgresql postgresql-contrib

# 4. Установка Nginx
log_info "Установка Nginx..."
apt-get install -y nginx

# 5. Создание системного пользователя
if ! id -u www-data > /dev/null 2>&1; then
    log_info "Создание пользователя www-data..."
    useradd -m -s /bin/bash www-data
fi

# 6. Создание директории проекта
log_info "Создание директории проекта..."
mkdir -p ${PROJECT_DIR}
chown -R www-data:www-data ${PROJECT_DIR}
chmod -R 755 ${PROJECT_DIR}

# 7. Клонирование/обновление репозитория
log_info "Клонирование репозитория..."
cd ${PROJECT_DIR}

if [ -d ".git" ]; then
    log_info "Обновление существующего репозитория..."
    sudo -u www-data git pull origin main
else
    log_info "Клонирование нового репозитория..."
    sudo -u www-data git clone ${REPO_URL} .
fi

# 8. Настройка PostgreSQL
log_info "Настройка PostgreSQL..."
sudo -u postgres psql -c "CREATE DATABASE ${PROJECT_NAME}_db;"
sudo -u postgres psql -c "CREATE USER ${PROJECT_NAME}_user WITH PASSWORD '${PROJECT_NAME}_password_123';"
sudo -u postgres psql -c "ALTER ROLE ${PROJECT_NAME}_user SET client_encoding TO 'utf8';"
sudo -u postgres psql -c "ALTER ROLE ${PROJECT_NAME}_user SET default_transaction_isolation TO 'read committed';"
sudo -u postgres psql -c "ALTER ROLE ${PROJECT_NAME}_user SET timezone TO 'UTC';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${PROJECT_NAME}_db TO ${PROJECT_NAME}_user;"

# 9. Настройка файла конфигурации PostgreSQL
log_info "Настройка доступа PostgreSQL..."
PG_HBA="/etc/postgresql/14/main/pg_hba.conf"
if [ -f "$PG_HBA" ]; then
    # Разрешаем доступ только с localhost
    sed -i '/^host.*all.*all.*0\.0\.0\.0\/0.*md5/d' "$PG_HBA"
    echo "host    all             all             127.0.0.1/32            md5" >> "$PG_HBA"
    systemctl restart postgresql
fi

# 10. Создание виртуального окружения и установка зависимостей
log_info "Создание виртуального окружения..."
sudo -u www-data python3 -m venv venv
sudo -u www-data ${PROJECT_DIR}/venv/bin/pip install --upgrade pip
sudo -u www-data ${PROJECT_DIR}/venv/bin/pip install -r requirements.txt

# 11. Создание файла окружения
log_info "Создание файла окружения..."
cat > ${ENV_FILE} << EOF
DJANGO_ENV=production
DJANGO_SECRET_KEY=$(openssl rand -base64 64 | tr -d '\n')
DB_NAME=${PROJECT_NAME}_db
DB_USER=${PROJECT_NAME}_user
DB_PASSWORD=${PROJECT_NAME}_password_123
DB_HOST=localhost
DB_PORT=5432
ALLOWED_HOSTS=localhost,127.0.0.1,*
DEBUG=False
STATIC_ROOT=/var/www/${PROJECT_NAME}/static
MEDIA_ROOT=/var/www/${PROJECT_NAME}/media
EOF

chmod 600 ${ENV_FILE}
chown www-data:www-data ${ENV_FILE}

# 12. Применение переменных окружения
export $(cat ${ENV_FILE} | xargs)

# 13. Настройка Django
log_info "Настройка Django..."
cd ${PROJECT_DIR}

# Создание production настроек если нужно
if [ ! -f "dvfukt/settings_production.py" ]; then
    cat > dvfukt/settings_production.py << 'EOF'
"""
Production settings for FEFU Lab project.
"""

from .settings import *
import os

# Безопасность
DEBUG = os.getenv('DEBUG', 'False') == 'True'
SECRET_KEY = os.getenv('DJANGO_SECRET_KEY')

# Домены
ALLOWED_HOSTS = os.getenv('ALLOWED_HOSTS', 'localhost,127.0.0.1').split(',')

# База данных PostgreSQL
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('DB_NAME'),
        'USER': os.getenv('DB_USER'),
        'PASSWORD': os.getenv('DB_PASSWORD'),
        'HOST': os.getenv('DB_HOST'),
        'PORT': os.getenv('DB_PORT'),
    }
}

# Статические файлы
STATIC_ROOT = os.getenv('STATIC_ROOT', '/var/www/fefu_lab/static')
STATIC_URL = '/static/'

# Медиа файлы
MEDIA_ROOT = os.getenv('MEDIA_ROOT', '/var/www/fefu_lab/media')
MEDIA_URL = '/media/'

# HTTPS настройки (если используется SSL)
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_SSL_REDIRECT = False  # Nginx будет обрабатывать SSL

# Логирование
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'file': {
            'level': 'ERROR',
            'class': 'logging.FileHandler',
            'filename': '/var/log/django/error.log',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['file'],
            'level': 'ERROR',
            'propagate': True,
        },
    },
}
EOF
fi

# Обновляем основной settings.py для использования production настроек
if ! grep -q "settings_production" dvfukt/settings.py; then
    echo "" >> dvfukt/settings.py
    echo "# Production settings" >> dvfukt/settings.py
    echo "try:" >> dvfukt/settings.py
    echo "    from .settings_production import *" >> dvfukt/settings.py
    echo "except ImportError:" >> dvfukt/settings.py
    echo "    pass" >> dvfukt/settings.py
fi

# 14. Сбор статических файлов
log_info "Сбор статических файлов..."
sudo -u www-data ${PROJECT_DIR}/venv/bin/python manage.py collectstatic --noinput

# 15. Создание директорий для медиа файлов
log_info "Создание директорий для медиа файлов..."
mkdir -p ${PROJECT_DIR}/media
mkdir -p ${PROJECT_DIR}/static
chown -R www-data:www-data ${PROJECT_DIR}/media ${PROJECT_DIR}/static
chmod -R 755 ${PROJECT_DIR}/media ${PROJECT_DIR}/static

# 16. Применение миграций
log_info "Применение миграций..."
sudo -u www-data ${PROJECT_DIR}/venv/bin/python manage.py migrate --noinput

# 17. Создание суперпользователя если нет
log_info "Создание суперпользователя..."
if ! sudo -u www-data ${PROJECT_DIR}/venv/bin/python manage.py shell -c "from django.contrib.auth.models import User; print(User.objects.filter(is_superuser=True).exists())" | grep -q "True"; then
    echo "from django.contrib.auth.models import User; User.objects.create_superuser('admin', 'admin@example.com', 'admin123')" | sudo -u www-data ${PROJECT_DIR}/venv/bin/python manage.py shell
fi

# 18. Настройка Gunicorn
log_info "Настройка Gunicorn..."
mkdir -p /var/log/gunicorn
chown -R www-data:www-data /var/log/gunicorn

# Копирование конфигурационных файлов Gunicorn
cp -r ${PROJECT_DIR}/deploy/gunicorn /var/www/fefu_lab/deploy/
cp ${PROJECT_DIR}/deploy/systemd/gunicorn.service /etc/systemd/system/

systemctl daemon-reload
systemctl enable gunicorn
systemctl restart gunicorn

# 19. Настройка Nginx
log_info "Настройка Nginx..."
cp ${PROJECT_DIR}/deploy/nginx/fefu_lab.conf /etc/nginx/sites-available/
ln -sf /etc/nginx/sites-available/fefu_lab.conf /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Создание директорий для логов Nginx
mkdir -p /var/log/nginx/fefu_lab

# Проверка конфигурации Nginx
if nginx -t; then
    systemctl restart nginx
else
    log_error "Ошибка в конфигурации Nginx!"
    exit 1
fi

# 20. Настройка firewall (если установлен)
if command -v ufw > /dev/null 2>&1; then
    log_info "Настройка firewall..."
    ufw allow 'Nginx Full'
    ufw allow ssh
    ufw --force enable
fi

# 21. Проверка работоспособности
log_info "Проверка работоспособности..."
sleep 5

# Проверка сервисов
SERVICES=("postgresql" "nginx" "gunicorn")
for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet $service; then
        log_info "Сервис $service работает"
    else
        log_error "Сервис $service не работает!"
        systemctl status $service
    fi
done

# Проверка доступности приложения
log_info "Проверка доступности приложения..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost > /dev/null; then
    log_info "Приложение доступно по адресу: http://localhost"
    log_info "Проверка статических файлов..."
    if curl -s -o /dev/null -w "%{http_code}" http://localhost/static/admin/css/base.css > /dev/null; then
        log_info "Статические файлы работают"
    else
        log_warn "Статические файлы могут быть недоступны"
    fi
else
    log_error "Приложение недоступно!"
    exit 1
fi

# 22. Финальный вывод
log_info "=========================================="
log_info "Деплой завершен успешно!"
log_info ""
log_info "Доступ к приложению: http://localhost"
log_info "Админка: http://localhost/admin"
log_info "Логи Nginx: /var/log/nginx/"
log_info "Логи Gunicorn: /var/log/gunicorn/"
log_info "Логи Django: /var/log/django/"
log_info ""
log_info "Учетные данные админа:"
log_info "  Логин: admin"
log_info "  Пароль: admin123"
log_info "=========================================="