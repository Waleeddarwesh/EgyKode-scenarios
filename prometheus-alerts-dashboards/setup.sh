#!/bin/bash
mkdir -p /root/obs/prometheus /root/obs/grafana/provisioning/datasources /root/obs/grafana/provisioning/dashboards

cat > /root/obs/prometheus/prometheus.yml <<'YML'
global:
  scrape_interval: 5s
  evaluation_interval: 5s

rule_files:
  - /etc/prometheus/rules/*.yml

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["localhost:9090"]
YML
mkdir -p /root/obs/prometheus/rules

cat > /root/obs/grafana/provisioning/datasources/prometheus.yml <<'YML'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
YML

cat > /root/obs/compose.yaml <<'YML'
services:
  prometheus:
    image: prom/prometheus:v2.54.1
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --web.enable-lifecycle
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/rules:/etc/prometheus/rules:ro

  grafana:
    image: grafana/grafana:11.2.0
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin
      GF_AUTH_ANONYMOUS_ENABLED: "true"
      GF_AUTH_ANONYMOUS_ORG_ROLE: Admin
    ports:
      - "3000:3000"
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
    depends_on:
      - prometheus
YML

docker pull -q prom/prometheus:v2.54.1 >/dev/null 2>&1
docker pull -q grafana/grafana:11.2.0 >/dev/null 2>&1
cd /root/obs && docker compose up -d >/dev/null 2>&1

for i in $(seq 1 40); do
  curl -s --max-time 3 http://localhost:9090/-/ready >/dev/null 2>&1 && break
  sleep 2
done
echo done
