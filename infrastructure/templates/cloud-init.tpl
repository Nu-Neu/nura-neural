#cloud-config
package_update: true
package_upgrade: true
packages:
  - ca-certificates
  - curl
  - gnupg

write_files:
  - path: /opt/nura/docker-compose.yml
    owner: root:root
    permissions: '0644'
    content: |
      ${indent(6, compose_yaml)}
  - path: /opt/nura/.env
    owner: root:root
    permissions: '0600'
    content: |
      ${indent(6, compose_env)}
  - path: /opt/nura/nginx.conf
    owner: root:root
    permissions: '0644'
    content: |
      ${indent(6, nginx_conf)}

runcmd:
  # Install Docker via official script
  - curl -fsSL https://get.docker.com | sh
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker ${admin_username}
  # Wait for Docker to be ready
  - sleep 15
  # Pull and start containers
  - cd /opt/nura && docker compose pull
  - cd /opt/nura && docker compose up -d
  # Log completion
  - echo "Docker Compose stack started at $(date)" >> /var/log/nura-setup.log
