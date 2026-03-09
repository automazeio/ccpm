# Integration Setup

Guide users through setting up a third-party service integration.

## Usage
```
/pm:integration-setup <service-name>
```

## Arguments
- `service-name`: The service to configure (e.g., sendgrid, stripe, openai)

## Instructions

### Step 1: Load Service Definition

```bash
SERVICE_FILE=".claude/integrations/registry/${ARGUMENTS}.yaml"
if [ ! -f "$SERVICE_FILE" ]; then
  echo "❌ Service not found: ${ARGUMENTS}"
  echo ""
  echo "Available services:"
  ls -1 .claude/integrations/registry/*.yaml | xargs -n1 basename | sed 's/.yaml$//'
  exit 1
fi
```

Read the service YAML file to get:
- `name`: Display name
- `signup.url`: Where to create account
- `signup.manual_steps`: Steps to get credentials
- `credentials`: What credentials to collect
- `validation`: How to verify credentials
- `free_tier`: Free tier information

### Step 2: Display Service Info

```
Setting up: {name}

{description}

Free tier: {free_tier.available ? free_tier.limits : "No free tier"}
```

### Step 3: Check for Existing Credentials

Check if credentials already exist for this service:

```bash
# Check environment file
grep -q "{credential.name}" .env 2>/dev/null && echo "Found existing credentials"
```

If credentials exist:
```
Found existing {name} credentials.

Options:
1. Use existing credentials
2. Replace with new credentials
3. Cancel

What would you like to do?
```

### Step 4: Guide Through Signup

If no existing credentials or user wants to replace:

```
To set up {name}, follow these steps:

1. Go to: {signup.url}
{for each step in signup.manual_steps}
{step_number + 2}. {step}
{/for}

When you have your credentials ready, paste them here.
Type 'skip' to configure later, 'help' for more guidance.
```

### Step 5: Collect Credentials

For each credential in the service definition:

```
Please enter your {credential.description}:
(Format: {credential.format})
```

**Important:**
- Don't echo back sensitive credentials
- Validate format if pattern is provided
- Store securely

### Step 6: Validate Credentials

If the service has a validation endpoint:

```bash
# Example validation for SendGrid
curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $SENDGRID_API_KEY" \
  https://api.sendgrid.com/v3/user/profile
```

If validation fails:
```
❌ Credential validation failed.

The API returned an error. Please check:
1. The key was copied correctly (no extra spaces)
2. The key has the correct permissions
3. Your account is active

Try again or type 'skip' to defer.
```

### Step 7: Store Credentials

Store validated credentials:

```bash
# Append to .env file (or project-specific .env)
echo "{credential.name}={value}" >> .env
```

For sensitive credentials, also offer to store in K8s secret:
```bash
kubectl create secret generic {service}-credentials \
  --from-literal={credential.name}={value} \
  -n {namespace} \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Step 8: Confirm Success

```
✅ {name} configured successfully!

Credentials stored:
  - {credential.name}: ****{last 4 chars}

Environment:
  - .env updated

SDK:
  npm install {sdk.npm}
  # or
  pip install {sdk.python}

Documentation:
  - Quickstart: {documentation.quickstart}
  - API Reference: {documentation.api_reference}
```

---

## Output

### Success
```
✅ {service} configured successfully!

Credentials stored:
  - {KEY_NAME}: ****{last 4}

Next steps:
  - Install SDK: npm install {package}
  - See docs: {quickstart_url}
```

### Skipped
```
⏳ {service} setup deferred.

To complete setup later:
  /pm:integration-setup {service}
```

### Error
```
❌ {service} setup failed: {reason}

To retry:
  /pm:integration-setup {service}
```

---

## Available Services

List available services with:
```bash
ls -1 .claude/integrations/registry/*.yaml | xargs -n1 basename | sed 's/.yaml$//'
```

Current registry includes:
- `openai` - AI/LLM (GPT models)
- `anthropic` - AI/LLM (Claude models)
- `sendgrid` - Email delivery
- `resend` - Email delivery
- `stripe` - Payments
- `clerk` - Authentication
- `pinecone` - Vector database
- `supabase` - Database + Auth + Storage
- `twilio` - SMS
- `posthog` - Analytics
- `sentry` - Error monitoring
- `upstash` - Redis/caching
- `cloudflare-r2` - Object storage
- `algolia` - Search
