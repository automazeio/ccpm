# Integration Verify

Validate all configured integrations by testing their credentials.

## Usage
```
/pm:integration-verify [service-name]
```

## Arguments
- `service-name` (optional): Verify a specific service. If omitted, verifies all.

## Instructions

### Step 1: Find Configured Integrations

Read the `.env` file (or project-specific env file) and match credentials against known services:

```bash
# Read .env and find matching service credentials
ENV_FILE="${WORK_DIR:-.}/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "No .env file found"
  exit 0
fi
```

For each service in `.claude/integrations/registry/`:
- Check if any of its credential names appear in .env
- If found, add to verification list

### Step 2: Verify Each Service

For each configured service:

```
Verifying {service.name}...
```

**Load service definition** from `.claude/integrations/registry/{service}.yaml`

**Extract credential values** from .env:
```bash
CREDENTIAL_VALUE=$(grep "^{credential.name}=" .env | cut -d'=' -f2-)
```

**Make validation request** based on service validation config:

```bash
# Example: API call validation
curl -s -o /tmp/response.json -w "%{http_code}" \
  -H "Authorization: Bearer $API_KEY" \
  "{validation.endpoint}"
```

**Check result:**
- Status code matches `validation.success_status` → ✅ Valid
- Status code is 401/403 → ❌ Invalid credentials
- Status code is 5xx → ⚠️ Service error
- Network error → ⚠️ Connection failed

### Step 3: Report Results

#### All Valid
```
✅ All integrations verified

| Service | Status | Last Checked |
|---------|--------|--------------|
| SendGrid | ✅ Valid | Just now |
| Stripe | ✅ Valid | Just now |
| OpenAI | ✅ Valid | Just now |
```

#### Some Invalid
```
⚠️ Integration verification completed with issues

| Service | Status | Issue |
|---------|--------|-------|
| SendGrid | ✅ Valid | - |
| Stripe | ❌ Invalid | Authentication failed |
| OpenAI | ⚠️ Error | Service unavailable |

To fix invalid credentials:
  /pm:integration-setup stripe

To retry:
  /pm:integration-verify
```

#### No Integrations
```
No integrations configured.

To set up integrations:
  /pm:integration-setup <service>

Available services:
  openai, anthropic, sendgrid, stripe, clerk, pinecone, ...
```

---

## Validation Methods

### api_call
Make HTTP request to validation endpoint:
```yaml
validation:
  method: api_call
  endpoint: https://api.service.com/v1/validate
  headers:
    Authorization: "Bearer {{API_KEY}}"
  success_status: 200
```

### basic_auth
Use HTTP Basic Authentication:
```yaml
validation:
  method: api_call
  endpoint: https://api.service.com/account
  auth: basic
  username: "{{ACCOUNT_SID}}"
  password: "{{AUTH_TOKEN}}"
  success_status: 200
```

### format_check
Just validate the credential format:
```yaml
validation:
  method: format_check
  format: url
  contains: "ingest.sentry.io"
```

### s3_compatible
Test S3-compatible storage:
```yaml
validation:
  method: s3_compatible
  endpoint: "https://{{ACCOUNT_ID}}.r2.cloudflarestorage.com"
  auth: aws_v4
```

---

## Output

### Success
```
✅ All {N} integrations verified

Services checked:
  - SendGrid: ✅ Valid
  - Stripe: ✅ Valid
  - OpenAI: ✅ Valid
```

### Partial
```
⚠️ {N} of {M} integrations have issues

Valid:
  - SendGrid: ✅

Issues:
  - Stripe: ❌ Invalid credentials
  - OpenAI: ⚠️ Service unavailable

Fix with: /pm:integration-setup <service>
```

### No Integrations
```
No integrations configured.

Set up integrations with:
  /pm:integration-setup <service>
```
