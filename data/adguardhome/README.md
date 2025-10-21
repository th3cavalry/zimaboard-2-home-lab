# AdGuard Home Data Directory

This directory contains runtime data and statistics for AdGuard Home.

## Contents
When AdGuard Home is running, this directory will contain:
- Query logs
- Statistics data
- Filter data and cache
- Session data

## Backups
It's recommended to backup this directory periodically if you want to preserve your query history and statistics. However, the main configuration in `configs/adguardhome/` is more critical for disaster recovery.

## Storage Usage
This directory can grow over time depending on your query log retention settings. Monitor disk usage and adjust retention settings in AdGuard Home's web interface if needed.
