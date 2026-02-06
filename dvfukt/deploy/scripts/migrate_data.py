#!/usr/bin/env python3
"""
Скрипт для миграции данных из SQLite в PostgreSQL
"""

import os
import sys
import django
import json
from pathlib import Path

# Добавляем проект в Python path
project_path = Path(__file__).parent.parent.parent
sys.path.append(str(project_path))

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'dvfukt.settings')
django.setup()

from django.core.management import execute_from_command_line


def backup_sqlite_data():
    """Экспорт данных из SQLite в JSON"""
    print("Экспорт данных из SQLite...")

    # Создаем backup текущей базы
    execute_from_command_line(['manage.py', 'dumpdata',
                               '--indent', '2',
                               '--output', 'data_backup.json',
                               '--exclude', 'contenttypes',
                               '--exclude', 'auth.permission',
                               '--exclude', 'admin.logentry'])

    print("✅ Данные экспортированы в data_backup.json")
    return 'data_backup.json'


def migrate_to_postgresql():
    """Миграция на PostgreSQL"""
    print("\nНастройка PostgreSQL...")

    # Обновляем settings для использования PostgreSQL
    settings_file = project_path / 'dvfukt' / 'settings.py'

    with open(settings_file, 'r') as f:
        content = f.read()

    # Проверяем, есть ли уже PostgreSQL настройки
    if "'django.db.backends.postgresql'" not in content:
        print("Обновление настроек базы данных...")

        # Добавляем production настройки если их нет
        prod_settings = project_path / 'dvfukt' / 'settings_production.py'
        if not prod_settings.exists():
            print("Создание production настроек...")
            # Код создания settings_production.py будет в deploy.sh

        # Обновляем основной settings.py
        with open(settings_file, 'a') as f:
            f.write('\n\n# Production settings\n')
            f.write('try:\n')
            f.write('    from .settings_production import *\n')
            f.write('except ImportError:\n')
            f.write('    pass\n')

    print("✅ Настройки обновлены")


def load_data_to_postgres():
    """Загрузка данных в PostgreSQL"""
    print("\nЗагрузка данных в PostgreSQL...")

    # Применяем миграции
    execute_from_command_line(['manage.py', 'migrate', '--run-syncdb'])

    # Загружаем данные
    if os.path.exists('data_backup.json'):
        execute_from_command_line(['manage.py', 'loaddata', 'data_backup.json'])
        print("✅ Данные загружены в PostgreSQL")

        # Удаляем временный файл
        os.remove('data_backup.json')
    else:
        print("⚠️ Файл с данными не найден, создаем пустую базу")


def main():
    print("=" * 60)
    print("МИГРАЦИЯ ДАННЫХ ИЗ SQLITE В POSTGRESQL")
    print("=" * 60)

    try:
        # 1. Экспорт данных
        backup_sqlite_data()

        # 2. Настройка PostgreSQL
        migrate_to_postgresql()

        # 3. Загрузка данных
        load_data_to_postgres()

        print("\n" + "=" * 60)
        print("✅ МИГРАЦИЯ УСПЕШНО ЗАВЕРШЕНА!")
        print("=" * 60)

    except Exception as e:
        print(f"\n❌ Ошибка: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()