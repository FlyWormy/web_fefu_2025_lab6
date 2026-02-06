import multiprocessing

# Биндинг
bind = "127.0.0.1:8000"

# Воркеры
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"

# Логирование
accesslog = "/var/log/gunicorn/access.log"
errorlog = "/var/log/gunicorn/error.log"
loglevel = "info"

# Перезагрузка
reload = False

# Таймауты
timeout = 120
keepalive = 5

# Безопасность
limit_request_line = 4096
limit_request_fields = 100
limit_request_field_size = 8190