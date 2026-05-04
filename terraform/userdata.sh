#!/bin/bash -xe
exec > >(tee /var/log/user-data.log) 2>&1

echo "==> Waiting for network connectivity..."
until curl -sf https://nodejs.org > /dev/null; do sleep 2; done

echo "==> Updating apt cache..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

echo "==> Installing Node.js 20 LTS via NodeSource..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

echo "==> Installing PostgreSQL 16..."
apt-get install -y postgresql-16

echo "==> Configuring PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

sudo -u postgres psql <<'PSQL'
CREATE DATABASE blogdb;
CREATE USER bloguser WITH ENCRYPTED PASSWORD 'blogpass';
GRANT ALL PRIVILEGES ON DATABASE blogdb TO bloguser;
ALTER DATABASE blogdb OWNER TO bloguser;
PSQL

echo "==> Installing git..."
apt-get install -y git

echo "==> Cloning application..."
git clone https://github.com/stuartMoorhouse/graphql-otel-elastic.git /opt/app

echo "==> Installing Node.js dependencies..."
cd /opt/app/app && npm ci

echo "==> Creating systemd service: graphql-blog..."
cat > /etc/systemd/system/graphql-blog.service <<EOF
[Unit]
Description=GraphQL Blog (Apollo Server + OTel)
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=${admin_username}
WorkingDirectory=/opt/app/app
Environment=NODE_ENV=production
Environment=DATABASE_URL=postgresql://bloguser:blogpass@localhost:5432/blogdb
Environment=OTEL_SERVICE_NAME=graphql-blog
Environment=OTEL_EXPORTER_OTLP_ENDPOINT=${elastic_apm_endpoint}
Environment=OTEL_EXPORTER_OTLP_HEADERS=Authorization=ApiKey ${elastic_apm_api_key}
Environment=OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production
Environment=PORT=4000
ExecStart=/usr/bin/node -r /opt/app/app/src/tracing.js /opt/app/app/src/server.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "==> Creating systemd service: graphql-blog-migrate..."
cat > /etc/systemd/system/graphql-blog-migrate.service <<EOF
[Unit]
Description=GraphQL Blog DB Migration (one-shot)
After=graphql-blog.service
Requires=graphql-blog.service

[Service]
Type=oneshot
User=${admin_username}
WorkingDirectory=/opt/app/app
Environment=DATABASE_URL=postgresql://bloguser:blogpass@localhost:5432/blogdb
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/node /opt/app/app/src/db-migrate.js
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo "==> Setting ownership of /opt/app..."
chown -R ${admin_username}:${admin_username} /opt/app

echo "==> Enabling and starting services..."
systemctl daemon-reload
systemctl enable --now graphql-blog
systemctl enable --now graphql-blog-migrate

echo "==> Bootstrap complete."
