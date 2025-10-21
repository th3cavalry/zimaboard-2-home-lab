# Lancache Configuration

This directory is reserved for Lancache configuration files.

The Lancache Monolithic container typically requires minimal configuration as it's designed to work out-of-the-box. The main configuration is done through DNS rewrites in AdGuard Home.

## How It Works
Lancache intercepts download requests for game content (Steam, Epic, etc.) and caches them locally. When properly configured with DNS rewrites, your devices will automatically use the cache for supported services.

## Storage
Cache data is stored in the volume configured in docker-compose.yml, typically on your HDD for maximum capacity.
