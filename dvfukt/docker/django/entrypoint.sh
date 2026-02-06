#!/bin/bash

# Функция для ожидания доступности базы данных
wait_for_db() {
    echo "Waiting for database..."
    while ! nc -z db 5432; do
        sleep 0.1
    done
    echo "Database is available!"
}

# Ожидание базы данных
wait_for_db

# Применение миграций
echo "Applying database migrations..."
python manage.py migrate --noinput

# Сборка статических файлов
echo "Collecting static files..."
python manage.py collectstatic --noinput

# Создание суперпользователя (только если нет пользователей)
echo "Creating superuser if needed..."
python manage.py shell -c "
from django.contrib.auth.models import User;
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@example.com', 'admin123')
    print('Superuser created')
else:
    print('Superuser already exists')
" || true

# Запуск команды
exec "$@"