server {
    listen 80;
    server_name _;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    location /api/ {
        proxy_pass http://fastapi:8000/;
    }

    location /miniflux/ {
        proxy_pass http://miniflux:8080/;
    }

    location /rsshub/ {
        proxy_pass http://rsshub:1200/;
    }
}
