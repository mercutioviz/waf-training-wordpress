# Quick Start Guide

Get up and running in 5 minutes!

## Prerequisites

- Linux server (Debian/Ubuntu)
- Docker and Docker Compose installed
- Port 8080 available

## Installation
1. Clone repository
git clone https://github.com/yourusername/waf-training-wordpress.git cd waf-training-wordpress

2. Configure
cp .env.example .env nano .env # Update WORDPRESS_SITE_URL with your server IP

3. Deploy
docker-compose up -d

4. Monitor setup (wait 5-10 minutes)
docker-compose logs -f setup

5. Access site
Frontend: http://YOUR_IP:8080
Admin: http://YOUR_IP:8080/wp-admin

## Verify Installation
# Run health check
./tools/health-check.sh

## Next Steps

1. Read the [SA Exercise Brief](docs/sa-exercise-brief.md)
2. Deploy your WAF
3. Start with [Exercise 1](exercises/01-header-value-length.md)

## Need Help?

- [Deployment Guide](docs/deployment-guide.md)
- [Troubleshooting](docs/troubleshooting.md)
- [GitHub Issues](https://github.com/yourusername/waf-training-wordpress/issues)

## Common Issues

**Can't access site:** Check firewall/security groups allow port 8080

**Setup fails:** Check logs with `docker-compose logs setup`

**Database errors:** Wait 2 minutes, then `docker-compose restart`

## Useful Commands

# View logs
docker-compose logs -f

# Restart
docker-compose restart

# Stop
docker-compose down

# Reset everything
docker-compose down -v docker-compose up -d
