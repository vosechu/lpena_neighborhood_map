# Deployment Guide

## Quick Start

**Generate your Rails secret key for production:**
```bash
# Generate a new secret key (run this locally, don't commit the output)
bundle exec rails secret

# Set it as an environment variable in production (never commit this!)
export SECRET_KEY_BASE="your_generated_secret_here"
```

⚠️ **NEVER commit secret keys to version control!**

**Usage:**
```bash
# Create first admin
ADMIN_EMAIL="admin@yourdomain.com" ADMIN_NAME="Admin" rails admin:create_first

# This will output a login URL that expires in 6 hours
```

## User Creation & Invitations

Your system now has **viral growth mechanics**:

1. **Admin creates users** via RailsAdmin or rake task
2. **Any user can invite others** by updating resident info with email
3. **Email added = automatic account creation** + welcome email
4. **Data changes = notification emails** (with opt-out)

Example workflow:
- User visits map, meets neighbor "John Doe"
- User updates John's info, adds email: `john@example.com` 
- ✨ **System automatically creates account for John**
- John gets welcome email with login link
- John can now access the map and add more neighbors

## Initial Setup

### 1. Generate Rails Secret Key

```bash
# Generate a new secret key
bundle exec rails secret

# Set in production environment (NEVER commit this to git!)
export SECRET_KEY_BASE="your_generated_secret_here"
```

**Alternative: Use Rails Encrypted Credentials**
```bash
# Edit encrypted credentials (recommended for production)
EDITOR="nano" rails credentials:edit

# Add to the file:
# secret_key_base: your_secret_here

# Rails will automatically use this in production
```

### 2. Create First Admin User

```bash
# Create the initial admin user
ADMIN_EMAIL="your-email@example.com" ADMIN_NAME="Your Name" rails admin:create_first

# Create additional admin users later
ADMIN_EMAIL="another-admin@example.com" ADMIN_NAME="Another Admin" rails admin:create

# List existing admins
rails admin:list
```

## Environment Variables

Set these environment variables in production:

```bash
# Required - GENERATE YOUR OWN, DON'T USE EXAMPLE VALUES!
SECRET_KEY_BASE="generate_with_rails_secret_command"
DATABASE_URL="postgresql://user:password@host:port/database"
REDIS_URL="redis://localhost:6379/0"

# Email Configuration
SMTP_HOST="your-smtp-server.com"
SMTP_PORT="587"
SMTP_USERNAME="your-smtp-username"
SMTP_PASSWORD="your-smtp-password"
SMTP_DOMAIN="your-domain.com"

# Application
APP_HOST="yourdomain.com"
RAILS_ENV="production"

# Sidekiq Protection (if needed)
SIDEKIQ_PASSWORD="your_sidekiq_password"

# Optional: Email deliverability
DMARC_POLICY="v=DMARC1; p=quarantine; rua=mailto:dmarc@yourdomain.com"
```

## Security Checklist

### 🔒 Application Security

1. **Secret Management** ⚠️ **CRITICAL**
   - ✅ Rails secret key generated with `rails secret`
   - ❌ **NEVER commit secrets to git**
   - ✅ Use environment variables or encrypted credentials
   - ✅ Database credentials secured
   - ✅ SMTP credentials secured
   - ⭐ **Recommended**: Use `rails credentials:edit` for production secrets

2. **User Authentication**
   - ✅ Devise configured with secure defaults
   - ✅ Password reset tokens expire (6 hours)
   - ✅ Account lockouts disabled (as requested)
   - ✅ Registration disabled (closed site)

3. **Authorization**
   - ✅ CanCanCan role-based access control
   - ✅ Admin-only access to RailsAdmin
   - ✅ All pages require authentication

4. **HTTPS/SSL**
   - ⚠️ **REQUIRED**: Configure SSL/TLS certificates
   - ⚠️ Set `config.force_ssl = true` in production.rb
   - ⚠️ Use HSTS headers for security

5. **Database Security**
   - ⚠️ Database password rotation
   - ⚠️ Database backups encrypted
   - ⚠️ Limited database user permissions

### 🛡️ Infrastructure Security

1. **Server Hardening**
   - ⚠️ Firewall configured (allow only 80, 443, SSH)
   - ⚠️ SSH key-based authentication only
   - ⚠️ Regular security updates
   - ⚠️ Fail2ban or similar intrusion detection

2. **Application Monitoring**
   - ⚠️ Log aggregation (consider Papertrail, Splunk)
   - ⚠️ Error tracking (consider Sentry, Bugsnag)
   - ⚠️ Performance monitoring (consider New Relic, DataDog)

3. **Backup Strategy**
   - ⚠️ Automated database backups
   - ⚠️ File storage backups
   - ⚠️ Test restore procedures

## Email Deliverability

### For Small Scale (Neighborhood App)

**DMARC is absolutely reasonable** for your scale and will significantly improve deliverability. Here's what to implement:

### 1. SPF Record
```dns
TXT @ "v=spf1 include:_spf.yourmailprovider.com ~all"
```

### 2. DKIM
Your email provider (SendGrid, Mailgun, etc.) will provide DKIM settings.

### 3. DMARC Record
Start with monitoring, then gradually enforce:

```dns
# Phase 1: Monitor only (start here)
TXT _dmarc "v=DMARC1; p=none; rua=mailto:dmarc@yourdomain.com"

# Phase 2: After 2-4 weeks, quarantine suspicious emails
TXT _dmarc "v=DMARC1; p=quarantine; rua=mailto:dmarc@yourdomain.com"

# Phase 3: After another 2-4 weeks, reject failing emails
TXT _dmarc "v=DMARC1; p=reject; rua=mailto:dmarc@yourdomain.com"
```

### 4. Email Service Recommendations

**For Neighborhood Scale (< 1000 emails/month):**
- **SendGrid** (12,000 free emails/month) ⭐ **Recommended**
- **Mailgun** (10,000 free emails/month)
- **Amazon SES** (very cheap, requires more setup)

**Benefits of managed services:**
- Built-in DKIM signing
- IP reputation management
- Bounce/complaint handling
- Better deliverability than self-hosted SMTP
- Easy DMARC compliance

### 5. Best Practices
- Use consistent "From" address (e.g., `noreply@yourdomain.com`)
- Include text version of HTML emails
- Implement unsubscribe headers
- Monitor bounce rates and complaints
- Warm up sending gradually
- **Test with your own email first**

## Production Configuration

### 1. Rails Configuration

Update `config/environments/production.rb`:

```ruby
# Force SSL
config.force_ssl = true

# Asset pipeline
config.assets.compile = false
config.assets.digest = true

# Logging
config.log_level = :info
config.log_tags = [:request_id]

# Email
config.action_mailer.delivery_method = :smtp
config.action_mailer.perform_deliveries = true
config.action_mailer.default_url_options = { host: ENV['APP_HOST'], protocol: 'https' }
```

### 2. Database Configuration

Ensure `config/database.yml` uses DATABASE_URL in production:

```yaml
production:
  <<: *default
  url: <%= ENV['DATABASE_URL'] %>
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
```

### 3. Redis Configuration

For Sidekiq job processing:

```ruby
# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end
```

## Deployment Commands

```bash
# 1. Setup database
rails db:create
rails db:migrate

# 2. Create admin user
ADMIN_EMAIL="admin@yourdomain.com" ADMIN_NAME="Admin" rails admin:create_first

# 3. Precompile assets
rails assets:precompile

# 4. Start services
# Application server (use Puma, Unicorn, or similar)
bundle exec puma -C config/puma.rb

# Background jobs
bundle exec sidekiq -e production
```

## Secret Management Best Practices

### ❌ **NEVER DO THIS:**
```bash
# Don't commit secrets to git
export SECRET_KEY_BASE="abc123..." # in a file that gets committed
```

### ✅ **DO THIS INSTEAD:**

**Option 1: Environment Variables**
```bash
# On your production server only
export SECRET_KEY_BASE="$(bundle exec rails secret)"
```

**Option 2: Rails Encrypted Credentials (Recommended)**
```bash
# Generate master key (keep this safe, don't commit)
EDITOR="nano" rails credentials:edit

# Add secrets to the encrypted file:
# secret_key_base: generated_secret_here
# database_password: db_password_here
```

**Option 3: External Secret Management**
- AWS Secrets Manager
- HashiCorp Vault
- Azure Key Vault
- Docker secrets

## Monitoring & Maintenance

### Daily
- Check application logs for errors
- Monitor email bounce rates

### Weekly  
- Review Sidekiq job failures
- Check disk space and database size
- Review DMARC reports

### Monthly
- Security updates
- Database cleanup/optimization
- Backup verification
- Access audit (remove inactive users)

## Quick Security Wins

1. **Enable SSL/HTTPS** (highest priority)
2. **Secure secret management** (use encrypted credentials)
3. **Set up email authentication** (SPF, DKIM, DMARC)
4. **Configure proper firewall rules**
5. **Set up basic monitoring/alerting**
6. **Implement automated backups**

## Emergency Contacts

Document who to contact for:
- DNS/domain issues
- Server/hosting problems  
- Email delivery problems
- Security incidents