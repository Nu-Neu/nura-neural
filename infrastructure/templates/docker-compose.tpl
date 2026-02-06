version: "3.9"

services:
  redis:
    image: ${redis_image}
    container_name: redis
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data

  miniflux:
    image: ${miniflux_image}
    container_name: miniflux
    depends_on:
      - redis
    restart: unless-stopped
    env_file:
      - /opt/nura/.env
    ports:
      - "8080:8080"

  rsshub:
    image: ${rsshub_image}
    container_name: rsshub
    depends_on:
      - redis
    restart: unless-stopped
    environment:
      - REDIS_URL=redis://redis:6379
    ports:
      - "1200:1200"

  fastapi:
    image: ${fastapi_image}
    container_name: fastapi
    restart: unless-stopped
    env_file:
      - /opt/nura/.env
    ports:
      - "8000:8000"

  nginx:
    image: ${nginx_image}
    container_name: nginx
    restart: unless-stopped
    depends_on:
      - fastapi
      - miniflux
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /opt/nura/nginx.conf:/etc/nginx/conf.d/default.conf:ro

volumes:
  redis-data:
