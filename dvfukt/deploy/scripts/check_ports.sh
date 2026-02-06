#!/bin/bash

# Проверка открытых портов
echo "Проверка открытых портов..."
echo "============================="

# Проверяем какие порты слушают
echo "1. Порты, слушающие на всех интерфейсах:"
netstat -tulpn | grep LISTEN | grep -E ':(80|5432|8000)'

echo ""
echo "2. Проверка доступности с хостовой машины:"
echo "   PostgreSQL (5432):"
nc -z -w5 localhost 5432 && echo "   ⚠️  Доступен!" || echo "   ✅ Закрыт"

echo "   Django (8000):"
nc -z -w5 localhost 8000 && echo "   ⚠️  Доступен!" || echo "   ✅ Закрыт"

echo "   Nginx (80):"
nc -z -w5 localhost 80 && echo "   ✅ Доступен (должен быть открыт)" || echo "   ❌ Закрыт"

echo ""
echo "3. Проверка доступности приложения:"
curl -s -o /dev/null -w "HTTP код: %{http_code}\n" http://localhost

echo ""
echo "4. Проверка статических файлов:"
curl -s -o /dev/null -w "Статические файлы: %{http_code}\n" http://localhost/static/admin/css/base.css

echo ""
echo "5. Проверка сервисов:"
systemctl is-active postgresql && echo "PostgreSQL: ✅" || echo "PostgreSQL: ❌"
systemctl is-active nginx && echo "Nginx: ✅" || echo "Nginx: ❌"
systemctl is-active gunicorn && echo "Gunicorn: ✅" || echo "Gunicorn: ❌"