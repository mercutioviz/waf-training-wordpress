# WAF Training WordPress Environment

A realistic WordPress + WooCommerce e-commerce site designed for training Solutions Architects on Web Application Firewall (WAF) configuration and fine-tuning, specifically focusing on false positive mitigation.

## 🎯 Purpose

This project creates a fully-functional outdoor gear e-commerce site ("Summit Outfitters") that naturally generates common WAF false positives related to request limits:

- **Header value length exceeded** (cookies, tokens)
- **Too many headers** (analytics, tracking, sessions)
- **Too many parameters** (product filters, form submissions)
- **Parameter value length exceeded** (product reviews, custom text)
- **Parameter name length exceeded** (page builder data)

## 🏗️ Architecture

- **WordPress** (latest) - Content management system
- **WooCommerce** - E-commerce platform
- **MySQL 8.0** - Database
- **Popular Plugins** - Elementor, Contact Form 7, WPForms, etc.
- **Realistic Data** - 250+ products, 75+ orders, 15 customers, 20 blog posts, 40+ reviews

## 📋 Prerequisites

- Linux server (Debian/Ubuntu recommended)
- Docker & Docker Compose installed
- 4GB+ RAM recommended
- 10GB+ disk space
- Port 8080 available

## 🚀 Quick Start

### 1. Clone the Repository

\`\`\`bash
git clone https://github.com/yourusername/waf-training-wordpress.git
cd waf-training-wordpress
\`\`\`

### 2. Configure Environment

\`\`\`bash
cp .env.example .env
\`\`\`

Edit \`.env\` to customize settings (or use defaults):

\`\`\`bash
# Key settings to review
WORDPRESS_SITE_URL=http://your-server-ip:8080
WORDPRESS_ADMIN_PASSWORD=YourSecurePassword123!
LISTEN_IP=0.0.0.0
LISTEN_PORT=8080
\`\`\`

### 3. Deploy

\`\`\`bash
docker-compose up -d
\`\`\`

The setup will automatically:
- Install WordPress and WooCommerce
- Install and configure all plugins
- Import products, posts, and pages
- Create user accounts
- Generate order history
- Add product reviews

**Setup time:** 5-10 minutes (depending on hardware)

### 4. Monitor Setup Progress

\`\`\`bash
docker-compose logs -f setup
\`\`\`

Wait for the message: "Setup Complete!"

### 5. Access the Site

- **Frontend:** http://your-server-ip:8080
- **Admin Panel:** http://your-server-ip:8080/wp-admin
- **Username:** admin (or your configured username)
- **Password:** Check your \`.env\` file

## 🎓 Training Scenario

### Student Briefing

You've been engaged to protect the website for **Summit Outfitters**, an online outdoor gear retailer.

**Your Mission:**
1. Deploy your WAF in front of the site
2. Enable protection policies  
3. Monitor logs for 24-48 hours
4. Identify and remediate false positives
5. Document your tuning decisions

### Expected False Positive Scenarios

#### 1. Header Value Length Exceeded
**Trigger:** Log in to admin panel with multiple active sessions  
**Solution:** Increase header value limit or whitelist specific cookies

#### 2. Too Many Headers
**Trigger:** Browse shop with analytics enabled  
**Solution:** Review which headers are legitimate, adjust limit

#### 3. Too Many Parameters
**Trigger:** Use advanced product search/filters  
**Solution:** Increase parameter limit for shop pages

#### 4. Parameter Value Length Exceeded
**Trigger:** Submit a long product review (2000+ characters)  
**Solution:** Increase limit for review submissions

#### 5. Parameter Name Length Exceeded
**Trigger:** Save a page with Elementor page builder  
**Solution:** Whitelist page builder endpoints

## 🔧 Management Commands

### View Logs
\`\`\`bash
docker-compose logs -f
docker-compose logs -f wordpress
docker-compose logs -f db
\`\`\`

### Restart Services
\`\`\`bash
docker-compose restart
\`\`\`

### Stop Services
\`\`\`bash
docker-compose down
\`\`\`

### Stop and Remove Data
\`\`\`bash
docker-compose down -v
\`\`\`

### Access WordPress Container
\`\`\`bash
docker exec -it waf-training-wordpress bash
\`\`\`

### WP-CLI Commands
\`\`\`bash
docker exec -it waf-training-wordpress wp --allow-root plugin list
docker exec -it waf-training-wordpress wp --allow-root user list
\`\`\`

## 📊 Site Statistics

**Default Configuration:**
- **Products:** ~250 (outdoor gear across 7 categories)
- **Orders:** ~75 (various statuses and dates)
- **Customers:** 15 (with order history)
- **Blog Posts:** 20 (outdoor/hiking content)
- **Pages:** 10+ (About, Contact, FAQ, etc.)
- **Reviews:** 40+ (3-5 star ratings)

## 🔐 Security Notes

**⚠️ This is a training environment - NOT for production use!**

- Default passwords are intentionally simple
- No SSL/TLS (use HTTP only)
- Database credentials are in plain text
- Some security hardening is disabled for training purposes

**For Training Use Only:** Deploy in isolated networks with proper firewall rules.

## 🐛 Troubleshooting

### Site Shows Database Connection Error
\`\`\`bash
docker-compose logs db | grep "ready for connections"
docker-compose restart
\`\`\`

### Port 8080 Already in Use
Edit \`.env\` and change \`LISTEN_PORT=8081\`, then:
\`\`\`bash
docker-compose down && docker-compose up -d
\`\`\`

### Reset Everything
\`\`\`bash
docker-compose down -v
docker-compose up -d
\`\`\`

## 🛠️ Customization

### Change Number of Products/Orders
Edit \`.env\`:
\`\`\`bash
NUM_PRODUCTS=500
NUM_ORDERS=150
\`\`\`

### Add More Plugins
Edit \`config/plugins.txt\` and add plugin slugs.

## 📚 Documentation

- [Deployment Guide](docs/deployment-guide.md)
- [SA Exercise Brief](docs/sa-exercise-brief.md)
- [Instructor Guide](docs/instructor-guide.md)
- [Troubleshooting](docs/troubleshooting.md)

## 🤝 Contributing

Contributions welcome! Please fork and submit pull requests.

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details.

## 🙋 Support

Report issues via [GitHub Issues](https://github.com/yourusername/waf-training-wordpress/issues)

---

**Ready to start training?** Follow the Quick Start guide above! 🚀
