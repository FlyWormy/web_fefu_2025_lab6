# docker/nginx/Dockerfile
FROM nginx:alpine

# Удаление дефолтных конфигураций
RUN rm -rf /etc/nginx/conf.d/*

# Копирование кастомной конфигурации
COPY docker/nginx/nginx.conf /etc/nginx/conf.d/default.conf

# HEALTHCHECK
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:80/ || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]