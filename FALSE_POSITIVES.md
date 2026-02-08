# Common WAF False Positive Scenarios

This document catalogs the intentional false positive triggers built into the TechGear Pro training environment, organized by WAF rule category.

## SQL Injection False Positives

### Product Names
- **15" MacBook Pro** - Contains `"` which can trigger string delimiter detection
- **O'Reilly's Gaming Mouse** - Contains `'` apostrophe, common SQL delimiter
- **USB-C to USB-A (3-Pack)** - Parentheses can trigger function call detection

### Product Searches
Users legitimately searching for:
- `O'Reilly` or `O'Brien` - Apostrophes in names
- `Size: 10-12` - Colons and ranges
- `Price > $100` or `Price < $50` - Comparison operators
- `SELECT your size` - SQL keywords in natural language
- `Men's 15" laptop bag` - Combined special characters

### Product Descriptions
- Technical specifications mentioning SQL databases
- Compatibility notes: "Works with MySQL 8.0+"
- Feature descriptions: "Query performance up to 10x faster"

### Customer Notes in Orders
- `"Please deliver between 9-5, use code #1234 at gate"` - Special characters
- `"Leave at door; security code is 1234"` - Numbers and commands
- `"Call me at 555-1234 OR text"` - SQL keyword OR

## Cross-Site Scripting (XSS) False Positives

### Contact Form Submissions
Technical support requests containing:
```
Error message: <configuration>
  <setting name="debug">true</setting>
</configuration>
```

### Product Reviews
- `"Fixed my 'Cannot connect' error"` - HTML-like quotes
- `"Works great! <3 this product"` - Less-than symbol
- `"Performance: 10/10 > expectations"` - Greater-than symbol

### Support Tickets
Users pasting error messages:
```
Error: <script>loadModule()</script> not found
Unable to parse XML: <element attribute="value">
Browser console shows: alert('connection failed')
```

### Blog Comments
- Discussions about web development with HTML examples
- Code snippets in technical discussions
- Markdown or BB-code formatting

## Path Traversal False Positives

### Support Requests
Error messages referencing legitimate paths:
- `"Log file at /var/log/app.log shows error"`
- `"Config file in /etc/myapp/config.conf"`
- `"Installed at C:\Program Files\MyApp\"`
- `"Check ~/.config/settings.ini"`

### Product Descriptions
- `"Compatible with /dev/ttyUSB0 devices"`
- `"Supports Windows paths like C:\Users\Documents"`
- `"Mount point: /mnt/storage"`

### File Upload Scenarios
- Users uploading `error.log` files
- Configuration files named `app.conf`
- Documentation PDFs with paths in content

## Command Injection False Positives

### Technical Discussions
- `"Run the command: npm install package-name"`
- `"Execute: sudo apt-get update && upgrade"`
- `"Use grep to find: grep -r 'error' /var/log/"`

### System Requirements
- `"Requires PowerShell 7.0+"`
- `"Compatible with bash 5.0 | zsh 5.8"`
- `"Install via: curl -fsSL script.sh | bash"`

### Error Messages
- `"Command not found: python3"`
- `"Permission denied: chmod +x file.sh"`
- `"Process terminated with signal 9"`

## HTTP Protocol Violations

### Legitimate Headers
- `User-Agent: curl/7.68.0` - Command-line tools
- `Referer: http://localhost:3000` - Development environments
- `Accept: application/json, text/plain, */*` - Modern API clients

### Content-Type Variations
- `multipart/form-data` with file uploads
- `application/x-www-form-urlencoded` with special characters
- `text/plain` for log file uploads

## Rate Limiting False Positives

### Legitimate High-Traffic Scenarios

#### Admin Operations
- Bulk editing 50 products at once
- Importing large product CSV
- Updating multiple orders simultaneously
- Theme customization with live preview

#### Automated Tools
- RSS feed readers polling `/feed/`
- SEO crawlers accessing `/sitemap.xml`
- Monitoring tools checking site health
- Backup plugins reading content

#### User Behavior
- Image gallery browsing (rapid image requests)
- Product comparison tools loading multiple products
- Search suggestions with autocomplete
- Infinite scroll pagination

## File Upload False Positives

### Legitimate File Types
- `.log` files for support tickets
- `.xml` configuration exports
- `.json` data files
- `.conf` configuration files
- `.txt` plain text documentation

### File Content
- Log files containing error messages with special characters
- Configuration files with XML/JSON syntax
- Text files with code snippets
- PDFs with technical content

## Session and Cookie Anomalies

### Expected WordPress Cookies
- `wordpress_logged_in_*` - Authentication
- `wp-settings-*` - User preferences
- `wordpress_test_cookie` - Cookie test
- `woocommerce_cart_hash` - Shopping cart
- `woocommerce_items_in_cart` - Cart counter

### Plugin Cookies
- `wordfence_waf_*` - Wordfence WAF
- `jetpack_sso_*` - Jetpack SSO
- Various analytics and marketing cookies

## AJAX and API Requests

### WordPress REST API
- `GET /wp-json/wp/v2/posts` - Fetch posts
- `GET /wp-json/wp/v2/users` - User queries
- `POST /wp-json/wc/v3/products` - WooCommerce API

### WordPress AJAX
- `POST /wp-admin/admin-ajax.php?action=*` - Various AJAX actions
- Cart operations: `?wc-ajax=add_to_cart`
- Search suggestions: `?action=product_search`

### Frontend Operations
- Live search with rapid requests
- Autocomplete firing on each keystroke
- Real-time inventory checks
- Dynamic price calculations

## Parameter Pollution and Injection

### URL Parameters
- `?orderby=price&order=desc` - Sorting
- `?min_price=50&max_price=200` - Filtering
- `?filter_color=red,blue,green` - Multiple values
- `?rating_filter=4,5` - Rating filters

### Search Queries
- `?s=laptop&category=electronics&price=100-500`
- `?q=gaming+mouse&sort=price_asc&brand[]=logitech&brand[]=razer`

## Response Code Anomalies

### Expected Non-200 Codes
- `301/302` - WordPress redirects
- `304` - Not Modified (caching)
- `401` - Login required (legitimate)
- `404` - Missing products/pages (user error)
- `410` - Discontinued products

## Training Exercises

### Exercise 1: Tuning SQL Injection Rules
1. Search for products: `O'Reilly`, `15"`, `SELECT`
2. Identify which WAF rules triggered
3. Create exceptions for search parameter (`?s=`)
4. Verify exceptions don't weaken security
5. Test with actual SQL injection attempts

### Exercise 2: Managing XSS in User Content
1. Submit contact form with XML config snippet
2. Post product review with HTML characters
3. Add comment with code discussion
4. Determine context-appropriate rules
5. Implement sanitization vs. blocking strategy

### Exercise 3: Path Traversal Context
1. Submit support ticket mentioning `/var/log/error.log`
2. Upload file named `config.conf`
3. Distinguish from actual traversal: `../../etc/passwd`
4. Create rules based on context (form submission vs. URL parameter)

### Exercise 4: Rate Limiting Calibration
1. Perform legitimate admin bulk operations
2. Simulate normal user browsing
3. Test API client access patterns
4. Set thresholds that block attacks but allow legitimate use
5. Implement graduated responses (warn -> throttle -> block)

## Decision Framework

When analyzing potential false positives, ask:

1. **Context**: Where did this request originate?
   - User input field (form, search, comment)
   - System operation (admin, plugin, cron)
   - External service (API, webhook, feed reader)

2. **Pattern**: What triggered the rule?
   - Special characters in expected context
   - Technical content in support channel
   - Legitimate automation or bulk operation

3. **Risk**: What's the worst case if we allow it?
   - Can the input reach dangerous contexts (DB query, OS command, file system)?
   - Is there input validation/sanitization downstream?
   - What data could be exposed or modified?

4. **Frequency**: How common is this pattern?
   - One-off edge case vs. common user behavior
   - Worth creating exception vs. user education

5. **Mitigation**: How can we safely allow it?
   - Scope exceptions narrowly (specific URLs, parameters)
   - Add additional validation requirements
   - Monitor for abuse of exceptions
   - Implement defense-in-depth

## Best Practices

### Rule Tuning
✅ **Do:**
- Create narrow, specific exceptions
- Document why each exception is needed
- Review exceptions regularly
- Test exceptions don't create security holes
- Monitor exception usage

❌ **Don't:**
- Disable entire rule categories
- Create overly broad exceptions
- Assume legitimate pattern can't be exploited
- Forget to re-evaluate exceptions over time

### Testing Approach
1. **Baseline** in detection-only mode
2. **Catalog** false positives
3. **Group** by pattern and context
4. **Exception** creation with narrow scope
5. **Validation** with security testing
6. **Monitoring** for abuse
7. **Iteration** as patterns evolve

### Documentation
For each exception, record:
- Rule ID and name
- Triggering pattern/payload
- Business justification
- URL/parameter scope
- Date created and by whom
- Review date
- Testing performed

## Additional Resources

### WordPress-Specific Considerations
- WordPress uses REST API extensively
- Plugins generate diverse traffic patterns
- Admin area needs more permissive rules
- WooCommerce checkout is sensitive
- Theme customization involves code-like content

### Common Gotchas
- Search functions accept any input
- Comments allow limited HTML by default
- File uploads vary by plugin
- AJAX requests may look unusual
- Cron jobs can trigger rate limits

### Testing Tools
- `test-waf.sh` - Automated testing script
- Browser developer tools - Manual request inspection
- curl - Command-line testing
- Postman - API request testing
- Custom scripts - Targeted scenario testing
