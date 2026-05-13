# Homelab

Personal AI homelab and self-hosted infrastructure stack.

## Stack

- Ubuntu Server
- Docker + Docker Compose
- Tailscale
- Caddy
- Ollama
- Open WebUI
- PostgreSQL
- Redis
- Uptime Kuma
- Grafana
- Prometheus
- Coolify
- n8n
- Portainer

## Structure

```text
homelab/
├── bootstrap.sh
├── install/
├── compose/
├── scripts/
└── docs/
```

## Goals

- Self-hosted AI workstation
- Personal VPS replacement
- Indie hacker deployment stack
- Local LLM experimentation
- Portable reproducible infrastructure

## Quick Start

```bash
git clone git@github.com:unfoundbox/homelab.git
cd homelab
chmod +x bootstrap.sh
sudo ./bootstrap.sh
```
