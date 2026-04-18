# Domain Setup with Route 53

## Overview
This guide walks you through purchasing a cheap domain and mapping it to your Nginx server on EC2 using AWS Route 53.

![Route 53 Architecture](https://docs.aws.amazon.com/images/Route53/latest/DeveloperGuide/images/DNS-overview.png)

## Prerequisites
- AWS Account
- Running EC2 instance with Nginx installed
- Public IP address of your EC2 instance

---

## Step 1: Purchase a Domain

### 1.1 Domain Options (Cheap)
| Registrar | Price Range | Notes |
|-----------|-------------|-------|
| **AWS Route 53** | $12-15/year | .com domains, integrated with AWS |
| **Namecheap** | $5-10/year | Frequent promotions, free WHOIS privacy |
| **GoDaddy** | $1-12/year | First year discounts |
| **Google Domains** | $12/year | Clean interface, good support |
| **Porkbun** | $5-8/year | Cheap renewals |

### 1.2 Purchase via Route 53
1. Navigate to **Route 53** → **Registered domains**
2. Click **Register Domain**
3. Search for your desired domain name
4. Add to cart and complete purchase (takes ~10 minutes to propagate)

![Route 53 Domain Registration](https://docs.aws.amazon.com/images/Route53/latest/DeveloperGuide/images/register-domain.png)

---

## Step 2: Create Hosted Zone in Route 53

### 2.1 Create Hosted Zone
1. Go to **Route 53** → **Hosted zones**
2. Click **Create hosted zone**
3. Enter your domain name: `example.com`
4. Select **Type: Public hosted zone**
5. Click **Create hosted zone**

### 2.2 Note Name Servers
After creation, Route 53 provides 4 name servers:
```
ns-1234.awsdns-56.org
ns-7890.awsdns-12.co.uk
ns-3456.awsdns-78.com
ns-9012.awsdns-34.net
```

**Important:** Update your domain registrar with these name servers if domain purchased outside AWS.

![Hosted Zone](https://docs.aws.amazon.com/images/Route53/latest/DeveloperGuide/images/hosted-zone.png)

---

## Step 3: Create DNS Records

### 3.1 Create A Record (Root Domain)
1. In your hosted zone, click **Create record**
2. Configure:
   - **Record name**: Leave blank (root domain)
   - **Record type**: A
   - **Value**: Your EC2 Public IP (e.g., 3.85.167.42)
   - **TTL**: 300 seconds
   - **Routing policy**: Simple routing

### 3.2 Create A Record (WWW Subdomain)
1. Click **Create record** again
2. Configure:
   - **Record name**: `www`
   - **Record type**: A
   - **Value**: Same EC2 Public IP
   - **TTL**: 300 seconds

### 3.3 Record Summary Table

| Record Name | Type | Value | Purpose |
|-------------|------|-------|---------|
| `example.com` | A | 3.85.167.42 | Root domain |
| `www.example.com` | A | 3.85.167.42 | WWW subdomain |
| `*.example.com` | A | 3.85.167.42 | Wildcard (optional) |

---

## Step 4: Configure Nginx for Domain

### 4.1 Update Nginx Server Block
```bash
# Edit default configuration or create new
sudo nano /etc/nginx/conf.d/example.com.conf
```

### 4.2 Add Server Configuration
```nginx
server {
    listen 80;
    server_name example.com www.example.com;
    
    root /usr/share/nginx/html;
    index index.html index.htm;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Logging
    access_log /var/log/nginx/example.com.access.log;
    error_log /var/log/nginx/example.com.error.log;
}
```

### 4.3 Test and Reload
```bash
# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

---

## Step 5: Verify DNS Propagation

### 5.1 Check DNS Propagation
```bash
# Using dig
dig example.com
dig www.example.com

# Using nslookup
nslookup example.com

# Using host
host example.com
```

### 5.2 Online DNS Checkers
- [whatsmydns.net](https://whatsmydns.net) - Global DNS propagation checker
- [dnschecker.org](https://dnschecker.org)

![DNS Propagation](https://www.whatsmydns.net/images/dns-propagation.png)

---

## Step 6: Test Domain Access

### 6.1 Browser Test
Open browser and navigate to:
```
http://example.com
http://www.example.com
```

### 6.2 curl Test
```bash
curl -I http://example.com
curl http://example.com
```

Expected output should show HTTP 200 and Nginx headers.

---

## Step 7: SSL/HTTPS Setup (Optional but Recommended)

### 7.1 Install Certbot
```bash
# Amazon Linux 2023
sudo dnf install certbot python3-certbot-nginx -y

# Ubuntu
sudo apt install certbot python3-certbot-nginx -y
```

### 7.2 Obtain SSL Certificate
```bash
sudo certbot --nginx -d example.com -d www.example.com
```

### 7.3 Auto-Renewal Test
```bash
sudo certbot renew --dry-run
```

### 7.4 Verify HTTPS
Access: `https://example.com` (should show secure lock icon)

---

## Troubleshooting

### Issue: Domain Not Resolving
```bash
# Check DNS propagation
# Wait 24-48 hours for full propagation
# Clear local DNS cache:
# macOS: sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
# Windows: ipconfig /flushdns
```

### Issue: Name Server Mismatch
```bash
# Verify name servers at registrar match Route 53
whois example.com | grep -i "name server"
```

### Issue: SSL Certificate Errors
```bash
# Check certificate validity
openssl s_client -connect example.com:443 -servername example.com

# View certificate details
echo | openssl s_client -servername example.com -connect example.com:443 2>/dev/null | openssl x509 -noout -text
```

---
