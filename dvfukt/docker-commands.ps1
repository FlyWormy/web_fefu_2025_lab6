# docker-commands.ps1
param(
    [string]$Command = "help"
)

# Цвета для вывода
$ErrorColor = "Red"
$InfoColor = "Green"
$WarningColor = "Yellow"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $InfoColor
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor $WarningColor
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $ErrorColor
}

# Проверка Docker
function Test-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Error "Docker не установлен!"
        exit 1
    }

    if (-not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
        Write-Error "Docker Compose не установлен!"
        exit 1
    }
}

switch ($Command) {
    "up" {
        Test-Docker
        Write-Info "Запуск приложения в development режиме..."
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml up --build
    }

    "up-prod" {
        Test-Docker
        Write-Info "Запуск приложения в production режиме..."
        docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
    }

    "down" {
        Test-Docker
        Write-Info "Остановка приложения..."
        docker-compose down
    }

    "logs" {
        Test-Docker
        Write-Info "Просмотр логов..."
        docker-compose logs -f
    }

    "web-logs" {
        Test-Docker
        Write-Info "Просмотр логов Django..."
        docker-compose logs -f web
    }

    "db-logs" {
        Test-Docker
        Write-Info "Просмотр логов базы данных..."
        docker-compose logs -f db
    }

    "nginx-logs" {
        Test-Docker
        Write-Info "Просмотр логов Nginx..."
        docker-compose logs -f nginx
    }

    "status" {
        Test-Docker
        Write-Info "Статус контейнеров..."
        docker-compose ps
    }

    "shell" {
        Test-Docker
        Write-Info "Вход в контейнер Django..."
        docker-compose exec web bash
    }

    "migrate" {
        Test-Docker
        Write-Info "Применение миграций..."
        docker-compose exec web python manage.py migrate
    }

    "createsuperuser" {
        Test-Docker
        Write-Info "Создание суперпользователя..."
        docker-compose exec web python manage.py createsuperuser
    }

    "collectstatic" {
        Test-Docker
        Write-Info "Сбор статических файлов..."
        docker-compose exec web python manage.py collectstatic --noinput
    }

    "test" {
        Test-Docker
        Write-Info "Запуск тестов..."
        docker-compose exec web python manage.py test
    }

    "backup" {
        Test-Docker
        Write-Info "Создание резервной копии базы данных..."
        $BackupFile = "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql"
        docker-compose exec db pg_dump -U django_user fefu_lab > $BackupFile
        Write-Info "Резервная копия сохранена в $BackupFile"
    }

    "clean" {
        Test-Docker
        Write-Info "Очистка Docker..."
        docker-compose down -v
        docker system prune -f
    }

    "help" {
        Write-Host "Использование: .\docker-commands.ps1 {команда}" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Команды:" -ForegroundColor Yellow
        Write-Host "  up              - Запуск в development режиме"
        Write-Host "  up-prod         - Запуск в production режиме (в фоне)"
        Write-Host "  down            - Остановка приложения"
        Write-Host "  logs            - Просмотр всех логов"
        Write-Host "  web-logs        - Просмотр логов Django"
        Write-Host "  db-logs         - Просмотр логов базы данных"
        Write-Host "  nginx-logs      - Просмотр логов Nginx"
        Write-Host "  status          - Статус контейнеров"
        Write-Host "  shell           - Вход в контейнер Django"
        Write-Host "  migrate         - Применение миграций"
        Write-Host "  createsuperuser - Создание суперпользователя"
        Write-Host "  collectstatic   - Сбор статических файлов"
        Write-Host "  test            - Запуск тестов"
        Write-Host "  backup          - Резервное копирование базы данных"
        Write-Host "  clean           - Очистка Docker"
    }

    default {
        Write-Error "Неизвестная команда: $Command"
        Write-Host "Используйте: .\docker-commands.ps1 help" -ForegroundColor Cyan
    }
}