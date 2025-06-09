# Email Safety System

This application includes a comprehensive email safety system to prevent test emails from reaching real users.

## 🛡️ **Protection Layers**

### 1. **Environment-Based Configuration**
- **Test**: `delivery_method: :test`, `perform_deliveries: false`
- **Development**: `delivery_method: :file` (emails saved to `tmp/mail/`)
- **Production**: Normal SMTP delivery (when configured)

### 2. **Email Safety Interceptor**
The `EmailSafetyInterceptor` class provides additional protection:

- **Test Environment**: Blocks all email delivery
- **Development Environment**: Logs email attempts, uses file delivery
- **Staging Environment**: Redirects all emails to safe test addresses
- **Production Environment**: Allows normal delivery with logging
- **Unknown Environments**: Blocks all email delivery as safety measure

### 3. **ApplicationMailer Safety Check**
The `ApplicationMailer` includes an `after_action` callback that:
- Raises an error if test environment tries to send to real email addresses
- Only allows `@example.com` addresses in test environment

## 🚨 **Safety Violations**

If you try to send an email to a real address in the test environment, you'll get:
```
EMAIL SAFETY VIOLATION: Test environment attempted to send email to real address: user@gmail.com
```

## ✅ **Safe Email Addresses for Testing**

Always use `@example.com` addresses in tests:
- `test@example.com`
- `user@example.com`
- `resident@example.com`

## 🔧 **Configuration Files**

- `config/initializers/email_safety.rb` - Main safety interceptor
- `config/environments/test.rb` - Test environment email config
- `config/environments/development.rb` - Development environment email config
- `app/mailers/application_mailer.rb` - Base mailer with safety checks

## 🧪 **Testing**

The email safety system is thoroughly tested in `spec/lib/email_safety_spec.rb`:
- Environment protection verification
- Interceptor behavior for all environments
- Email redirection logic
- Safety violation detection

## 📝 **Development Workflow**

1. **Writing Tests**: Always use `@example.com` addresses
2. **Development**: Emails are saved to `tmp/mail/` directory
3. **Staging**: Emails are redirected to safe test addresses
4. **Production**: Normal email delivery (when SMTP is configured)

## 🚀 **Production Setup**

To enable real email delivery in production, configure SMTP settings in `config/environments/production.rb`:

```ruby
config.action_mailer.smtp_settings = {
  user_name: Rails.application.credentials.dig(:smtp, :user_name),
  password: Rails.application.credentials.dig(:smtp, :password),
  address: "smtp.example.com",
  port: 587,
  authentication: :plain
}
```

## 🔍 **Debugging**

The system logs all email attempts with detailed information:
- Environment detection
- Email recipients
- Safety actions taken
- Redirection details (in staging)

Check your Rails logs for `Email Safety:` messages to debug email issues.

## 📧 **Email Opt-Out System**

The application includes a comprehensive email opt-out system that respects user preferences:

### **Two Types of Opt-Out**

1. **Email Notifications Only**: Users can stop receiving emails but remain in the directory
2. **Complete Directory Removal**: Users can hide from the directory entirely (also stops emails)

### **Unsubscribe Features**

- **One-Click Unsubscribe**: Gmail-style unsubscribe button support via `List-Unsubscribe` headers
- **Quick Unsubscribe URL**: `/unsubscribe/:token` for instant email opt-out
- **Full Options Page**: `/opt-out/:token` for choosing between email opt-out or directory hiding

### **Email Respect**

The `ResidentMailer.deliver_data_change_notification` class method automatically:
- Checks `email_notifications_opted_out` flag before sending
- Skips email delivery for opted-out residents
- Includes unsubscribe links in all emails

### **Routes**

- `GET /unsubscribe/:token` - Instant email opt-out (one-click)
- `GET /opt-out/:token` - Privacy options page
- `POST /opt-out/:token/opt-out-emails` - Email opt-out action
- `POST /opt-out/:token/hide-directory` - Directory hiding action

### **Testing**

Comprehensive tests in `spec/requests/opt_outs_spec.rb` cover:
- Token validation and expiration
- Email opt-out functionality
- Directory hiding functionality
- Email header verification
- Conditional email delivery
