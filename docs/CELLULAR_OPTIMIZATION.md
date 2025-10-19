# Cellular Network Optimization Guide

## Overview

This guide explains how to optimize your ZimaBoard 2 homelab for cellular internet connectivity using the GL.iNet X3000 router. The setup includes intelligent caching, bandwidth conservation, and performance optimization for gaming, streaming, and general web usage.

## Squid Proxy Caching System

### What Gets Cached

**Gaming Content (Long-term caching - 3+ days)**:
- Steam depot files and game chunks
- Epic Games manifests and content
- Origin patches and updates
- Gaming platform installers and libraries
- Game asset files (.pak, .vpk, .gcf, .ncf)

**Streaming Content (Medium-term caching - 12-24 hours)**:
- YouTube video segments
- Netflix/Hulu/Disney+ chunks
- Twitch stream segments
- Spotify/Apple Music audio files
- Video thumbnails and previews

**Software Updates (Long-term caching - 7+ days)**:
- Windows Update files
- macOS software updates
- Linux package repositories
- Browser updates and extensions
- Mobile app updates

**Web Content (Extended caching - 7+ days)**:
- Images (JPEG, PNG, WebP, SVG)
- Stylesheets and JavaScript files
- Web fonts and icons
- CDN content from major providers

### Expected Bandwidth Savings

**Typical Savings by Category**:
- **Gaming**: 70-90% for repeated downloads
- **Streaming**: 30-60% for rewatched content
- **Software Updates**: 80-95% for multiple devices
- **Web Browsing**: 40-70% for static content
- **Overall Average**: 50-75% bandwidth reduction

## GL.iNet X3000 Router Configuration

### Method 1: Automatic Proxy Configuration (Recommended)

1. **Access GL.iNet Admin Panel**:
   ```
   http://192.168.8.1
   ```

2. **Navigate to Advanced → Network → Proxy**:
   - Enable "Use Proxy Server"
   - Proxy Type: HTTP
   - Proxy Server: `192.168.8.105`
   - Port: `3128`
   - Apply settings

3. **Configure DNS**:
   - Navigate to Advanced → Network → DNS
   - Primary DNS: `192.168.8.100` (Pi-hole)
   - Secondary DNS: `1.1.1.1`
   - Apply settings

### Method 2: Manual Device Configuration

For devices that don't use router proxy settings:

**Windows**:
1. Settings → Network & Internet → Proxy
2. Manual proxy setup: ON
3. Address: `192.168.8.105`
4. Port: `3128`

**macOS**:
1. System Preferences → Network → Advanced → Proxies
2. Check "Web Proxy (HTTP)"
3. Server: `192.168.8.105`
4. Port: `3128`

**Linux**:
```bash
export http_proxy=http://192.168.8.105:3128
export https_proxy=http://192.168.8.105:3128
```

**Android**:
1. WiFi Settings → Advanced → Proxy
2. Manual configuration
3. Hostname: `192.168.8.105`
4. Port: `3128`

**iOS**:
1. WiFi Settings → Configure Proxy
2. Manual
3. Server: `192.168.8.105`
4. Port: `3128`

## Gaming Platform Optimization

### Steam Configuration

1. **Steam Client**:
   - Steam → Settings → Downloads
   - Clear Download Cache (first time only)
   - Restart Steam

2. **Bandwidth Monitoring**:
   ```bash
   # Monitor Steam cache hits
   pct exec 105 -- tail -f /var/log/squid/access.log | grep steam
   ```

### Epic Games Launcher

1. **Epic Settings**:
   - Settings → General → Download settings
   - Enable "Throttle downloads" if needed

2. **Cache Verification**:
   ```bash
   # Check Epic Games cache statistics
   pct exec 105 -- squid-bandwidth 1440 | grep epic
   ```

### Console Gaming (PlayStation/Xbox)

1. **Network Settings**:
   - Configure console to use proxy
   - PS5: Settings → Network → Set Up Internet Connection → Advanced
   - Xbox: Settings → Network → Advanced settings → Proxy

2. **Game Update Optimization**:
   - Large game updates will be cached for other consoles
   - Significant bandwidth savings for multi-console households

## Streaming Optimization

### YouTube/Video Platforms

**Optimizations Applied**:
- Video segment caching
- Thumbnail pre-loading
- Reduced rebuffering
- Faster video start times

**Expected Performance**:
- 40-60% bandwidth reduction for rewatched content
- Improved buffering on poor cellular signal
- Faster loading of previously viewed channels

### Music Streaming

**Supported Platforms**:
- Spotify (web player and some content)
- Apple Music (web components)
- YouTube Music
- SoundCloud

**Cache Benefits**:
- Repeated song plays don't use bandwidth
- Album art and metadata cached
- Reduced loading times

## Bandwidth Monitoring and Management

### Real-time Monitoring

```bash
# View current cache statistics
pct exec 105 -- squid-stats

# Monitor bandwidth savings (last hour)
pct exec 105 -- squid-bandwidth 60

# Watch live traffic
pct exec 105 -- tail -f /var/log/squid/access.log
```

### Daily Reports

The system automatically generates reports every 6 hours:

```bash
# View daily statistics
pct exec 105 -- cat /var/log/squid/daily-stats.log
```

### Cache Management

```bash
# Clear cache if needed (emergency only)
pct exec 105 -- squid-cleanup

# Check cache disk usage
pct exec 105 -- df -h /var/spool/squid

# View top cached domains
pct exec 105 -- squid-stats | grep "Top Cached Domains" -A 10
```

## Cellular Data Plan Optimization

### Data Usage Tracking

**Monthly Monitoring**:
1. Track baseline usage before optimization
2. Monitor cache hit ratios weekly
3. Calculate actual bandwidth savings
4. Adjust cache settings if needed

**Expected Results**:
- 50-75% reduction in total data usage
- Improved performance during peak hours
- Better gaming/streaming experience

### Cost Savings

**Example Savings (Monthly)**:
- **Before**: 500GB cellular data usage
- **After**: 150-250GB actual usage
- **Savings**: 250-350GB monthly
- **Cost Impact**: $50-100+ monthly savings (depending on plan)

## Advanced Configuration

### Gaming-Specific Optimizations

**Steam Content Servers**:
```bash
# Add Steam CDN optimization
pct exec 105 -- bash -c "echo 'refresh_pattern -i steam.*/(depot|chunk) 43200 90% 259200 override-expire ignore-no-cache' >> /etc/squid/squid.conf"
```

**Console Gaming**:
```bash
# Optimize for PlayStation/Xbox content
pct exec 105 -- bash -c "echo 'refresh_pattern -i (playstation|xbox).*\.(pkg|xvc) 43200 90% 259200 override-expire ignore-no-cache' >> /etc/squid/squid.conf"
```

### Streaming Optimizations

**Video Quality Management**:
- Cache multiple quality levels
- Optimize for 1080p content
- Reduce 4K caching to save space

**Live Stream Handling**:
- Short-term buffering for live content
- Avoid caching live streams
- Optimize for VOD content

## Troubleshooting

### Common Issues

**Slow Initial Downloads**:
- First-time downloads will be slower
- Subsequent downloads will be much faster
- Be patient during initial cache population

**Cache Miss Rate Too High**:
```bash
# Check cache configuration
pct exec 105 -- squid -k parse

# Verify cache directories
pct exec 105 -- ls -la /var/spool/squid
```

**High Cache Disk Usage**:
```bash
# Monitor cache growth
pct exec 105 -- du -sh /var/spool/squid

# Clean old cache if needed
pct exec 105 -- find /var/spool/squid -type f -mtime +7 -delete
```

### Performance Tuning

**Memory Optimization**:
```bash
# Increase cache memory if available
pct set 105 --memory 3072

# Restart container
pct restart 105
```

**Storage Optimization**:
```bash
# Increase cache storage if needed
pct resize 105 scsi0 +20G
```

## Monitoring Dashboard

### Grafana Integration

The system includes pre-configured Grafana dashboards for:
- Real-time bandwidth usage
- Cache hit/miss ratios
- Top cached domains
- Data savings over time
- Gaming/streaming specific metrics

Access via: `http://192.168.8.107:3000`

### Alert Configuration

**Set up alerts for**:
- Cache disk usage > 90%
- Cache hit ratio < 30%
- Proxy service downtime
- High bandwidth usage spikes

## Best Practices

### Initial Setup

1. **Warm the Cache**:
   - Update Steam library
   - Browse frequently used websites
   - Stream some YouTube videos
   - Download OS updates

2. **Monitor Performance**:
   - Check cache statistics daily for first week
   - Adjust settings based on usage patterns
   - Fine-tune cache sizes

3. **Regular Maintenance**:
   - Weekly cache statistics review
   - Monthly cache cleanup if needed
   - Quarterly configuration optimization

### Long-term Operation

**Monthly Tasks**:
- Review bandwidth savings reports
- Update Squid configuration if needed
- Check for software updates
- Verify cache disk health

**Quarterly Tasks**:
- Analyze usage patterns
- Optimize cache rules
- Update gaming platform configurations
- Review cellular data plan usage

This cellular optimization setup should provide significant bandwidth savings and improved performance for your ZimaBoard 2 homelab on cellular internet.
