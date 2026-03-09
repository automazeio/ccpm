# Gather Credentials

Collect required credentials for integrations detected in scope document.

## Usage
```
/pm:gather-credentials [session-name]
```

## Arguments
- `session-name` (optional): Name of the scoped session. If not provided, auto-detects from `.claude/scopes/`

## Output

**Files Created:**
- `.env` - Actual credential values (gitignored)
- `.env.template` - Template with placeholders (tracked in git)
- `.claude/credentials.yaml` - Collection metadata

---

## Instructions

### Step 1: Initialize and Validate

**Auto-detect scope if not provided:**

```bash
SESSION_NAME="$ARGUMENTS"

# If no session name provided, auto-detect
if [ -z "$SESSION_NAME" ]; then
  # Count scopes
  scope_count=$(ls -1d .claude/scopes/*/ 2>/dev/null | wc -l)

  if [ "$scope_count" -eq 0 ]; then
    # No scopes found
    echo "❌ No scopes found"
  elif [ "$scope_count" -eq 1 ]; then
    # Use the only scope
    SESSION_NAME=$(ls -1d .claude/scopes/*/ | head -1 | xargs basename)
  else
    # Use most recently modified scope
    SESSION_NAME=$(ls -1td .claude/scopes/*/ | head -1 | xargs basename)
  fi
fi

SCOPE_DIR=".claude/scopes/$SESSION_NAME"
ARCH_DOC="$SCOPE_DIR/04_technical_architecture.md"
MAPPING_FILE=".claude/templates/credential-mapping.json"
```

**Check prerequisites:**

If no scopes exist:
```
❌ No scopes found in .claude/scopes/
Run: ./interrogate.sh --extract <session-name>
```

If `04_technical_architecture.md` doesn't exist:
```
❌ Architecture document not found
Run: /pm:extract-findings {session-name}
```

If credential mapping doesn't exist:
```
❌ Credential mapping not found: .claude/templates/credential-mapping.json
```

Read both the architecture document and the credential mapping JSON.

---

### Step 2: Detect Integrations

Scan `04_technical_architecture.md` for integrations.

**Look for sections like:**
- "Integration Requirements"
- "External Systems"
- "Third-party Services"
- "Technology Stack" (for databases, caching, etc.)

**Extract integration names by matching against known integrations in credential-mapping.json:**

Known integrations from mapping:
- Keycloak, Auth0, Firebase (authentication)
- PostgreSQL, MongoDB, Supabase (databases)
- Redis, Elasticsearch (data stores)
- AWS S3, Cloudflare (infrastructure)
- Stripe (payments)
- SendGrid, Mailgun (email)
- Twilio, Slack (communication)
- GitHub (version control)
- OpenAI, Anthropic (AI)
- Sentry (monitoring)
- RabbitMQ (messaging)

Also detect from context:
- If "OAuth" or "OIDC" mentioned → check for Keycloak/Auth0
- If "file storage" or "uploads" → check for AWS S3
- If "payments" or "billing" → check for Stripe
- If "email" → check for SendGrid/Mailgun
- If "caching" or "session store" → check for Redis

Create list of detected integrations.

---

### Step 3: Interactive Confirmation

Display detected integrations and allow user to confirm/modify.

Use the AskUserQuestion tool:

**Question 1:** Confirm detected integrations

```
Detected integrations from scope document:

1. {Integration 1}
2. {Integration 2}
3. {Integration 3}
...

Are these correct? You can also add additional integrations.
```

**Options:**
- "Yes, these are correct"
- "Add more integrations"
- "Remove some integrations"
- "Start over with manual list"

If user chooses "Add more integrations":
- Ask which integrations to add from the known list
- Allow custom integration names

If user chooses "Remove some integrations":
- Ask which to remove

Store final confirmed list of integrations.

---

### Step 3.5: Collect Purpose for Each Integration

**CRITICAL: For each confirmed integration, ask about its purpose.**

Use the AskUserQuestion tool for each integration:

```
What is the purpose of {Integration Name} in your application?

Examples:
- "Payment processing and subscription billing"
- "Accounting and invoicing sync"
- "User authentication and SSO"
- "Email notifications and transactional emails"
```

**Options (with "Other" always available):**
- Common purpose based on integration type (e.g., "Payment processing" for Stripe)
- Second common purpose
- Third option
- Other (user provides custom purpose)

**Store the purpose with each integration for database storage.**

This purpose will be used to:
1. Document why each integration exists
2. Help with debugging and maintenance
3. Generate better PRD context

---

### Step 4: Collect Credentials

For each confirmed integration, collect credentials.

**For each integration:**

1. Look up credentials in mapping JSON
2. For each credential:
   - Show name and description
   - Show default value if available
   - Indicate if required or optional
   - Note if sensitive (will be masked)

**Use AskUserQuestion for each credential that doesn't have a default:**

For sensitive credentials, note that the user should enter the value carefully as it won't be displayed back.

**Allow special values:**
- `defer` - Mark as deferred (collect later)
- Empty for optional fields - Skip the credential
- Accept defaults by confirming

**For each credential collected:**
- Validate against pattern if defined
- Store in memory (never log sensitive values)

**For unknown integrations (not in mapping):**

Ask user to provide credential names one at a time:
```
Integration "{name}" not in mapping table.

Enter credential name (or 'done' to finish):
```

For each custom credential, ask:
- Name (environment variable name)
- Description
- Is it required?
- Is it sensitive?
- Default value (optional)

---

### Step 5: Generate Files

**Get current datetime:**
```bash
CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
```

**Create `.env` file in project root:**

```bash
# Generated by /pm:gather-credentials on {datetime}
# Session: {session-name}

# {Integration 1}
{KEY1}={value1}
{KEY2}={value2}

# {Integration 2}
{KEY3}={value3}
{KEY4}={value4}

# ...
```

**Do NOT include:**
- Deferred credentials (marked with `defer`)
- Optional credentials left empty
- Comments about sensitive values

**Create `.env.template` file in project root:**

```bash
# Template generated by /pm:gather-credentials on {datetime}
# Copy this to .env and fill in your values
# Session: {session-name}

# {Integration 1}
# {Description for KEY1}
{KEY1}={default or empty}
# {Description for KEY2}
{KEY2}=

# {Integration 2}
# {Description for KEY3}
{KEY3}={default or empty}

# ...
```

Include ALL credentials (even deferred) with descriptions.

---

### Step 6: Security Validation

**Check .gitignore:**

```bash
if ! grep -q "^\.env$" .gitignore 2>/dev/null; then
  # Add .env to .gitignore
  echo "" >> .gitignore
  echo "# Environment files" >> .gitignore
  echo ".env" >> .gitignore
  echo ".env.local" >> .gitignore
  echo ".env.*.local" >> .gitignore
fi
```

**Check if .env is tracked:**

```bash
if git ls-files --error-unmatch .env 2>/dev/null; then
  echo "❌ ERROR: .env is tracked in git!"
  echo "Remove with: git rm --cached .env"
  echo "Then commit the change."
fi
```

---

### Step 7: Save to Database (Encrypted)

**CRITICAL: Store credentials in PostgreSQL with encryption.**

For each integration, create an `IntegrationCredential` record:

```python
from backend.db.interview import CredentialRepository, check_encryption_configured
from backend.extraction.interview.models import (
    IntegrationCredential,
    IntegrationEnvironment,
    CredentialStatus,
)
from sqlalchemy import create_engine
import os

# Check encryption is configured
if not check_encryption_configured():
    print("⚠️  CREDENTIAL_ENCRYPTION_KEY not set in .env")
    print("Generate with: python -c 'from backend.services.credential_encryption_service import CredentialEncryption; print(CredentialEncryption.generate_key())'")
    # Skip database storage but continue with .env generation
else:
    # Create database connection
    engine = create_engine(os.getenv("DATABASE_URL"))
    repo = CredentialRepository(engine)

    # For each integration
    for integration in confirmed_integrations:
        cred = IntegrationCredential(
            integration_type=integration["type"],  # e.g., "stripe", "quickbooks"
            integration_name=integration["name"],  # e.g., "Stripe Production"
            purpose=integration["purpose"],        # e.g., "Payment processing"
            environment=IntegrationEnvironment.PRODUCTION,
            scope_name=session_name,
            status=CredentialStatus.PENDING if deferred else CredentialStatus.ACTIVE,
            # Credential values (will be encrypted by repository)
            api_key_encrypted=integration.get("api_key"),
            api_secret_encrypted=integration.get("api_secret"),
            username=integration.get("username"),
            password_encrypted=integration.get("password"),
            oauth_client_id=integration.get("client_id"),
            oauth_client_secret_encrypted=integration.get("client_secret"),
            # Additional fields as needed
            additional_secrets=integration.get("additional", {}),
        )

        # Upsert (insert or update)
        cred_id = repo.upsert(cred)
        print(f"  ✓ {integration['type']}: Stored (ID: {cred_id})")
```

**Security Notes:**
- All `*_encrypted` fields are automatically encrypted by `CredentialRepository`
- Encryption uses AES-256-GCM with unique nonce per value
- Encryption key must be set in `CREDENTIAL_ENCRYPTION_KEY` environment variable

---

### Step 8: Save State

**Create credentials.yaml at project level:**

```yaml
gathered: {datetime}
session: {session-name}
integrations:
  - name: {Integration1}
    purpose: {purpose1}
    credentials_count: {n}
    db_id: {database_id}
  - name: {Integration2}
    purpose: {purpose2}
    credentials_count: {n}
    db_id: {database_id}
total_credentials: {total}
deferred_credentials: {count}
validation_passed: true
env_file: .env
template_file: .env.template
database_stored: true
encryption_enabled: true
```

Write to: `.claude/credentials.yaml`

---

### Step 9: Present Summary

```
=== Credential Gathering Complete ===

Session: {session-name}

Integrations Configured:
- {Integration 1}: {purpose1} ({n} credentials)
- {Integration 2}: {purpose2} ({n} credentials)
...

Summary:
- Total credentials: {total}
- Deferred: {count} (collect before build)
- Validated: ✓

Files Created:
- .env (actual values)
- .env.template (for sharing/onboarding)
- .claude/credentials.yaml (metadata)

Database Storage:
- ✓ Credentials encrypted with AES-256-GCM
- ✓ Stored in integration_credentials table
- ✓ Linked to scope: {session-name}

Security:
- ✓ .env added to .gitignore
- ✓ .env not tracked in git
- ✓ Database fields encrypted at rest

{If deferred > 0:}
⚠ Deferred credentials: {count}
  Run this command again to complete them before building.

{If encryption not configured:}
⚠ Database storage skipped - CREDENTIAL_ENCRYPTION_KEY not set
  Generate key: python -c "from backend.services.credential_encryption_service import CredentialEncryption; print(CredentialEncryption.generate_key())"
  Add to .env: CREDENTIAL_ENCRYPTION_KEY=<generated-key>
  Re-run: /pm:gather-credentials {session-name}

Next Steps:
1. Review .env for accuracy
2. Build application: ./interrogate.sh --build {session-name}
```

---

## Error Handling

| Error | Resolution |
|-------|------------|
| Scope not found | Run /pm:extract-findings first |
| Architecture doc missing | Run /pm:extract-findings first |
| Mapping file missing | Check .claude/templates/credential-mapping.json |
| Pattern validation failed | Show error, allow re-entry |
| .env tracked in git | Block until git rm --cached .env |

---

## Important Rules

1. **Never log sensitive values** - Only show masked output
2. **Validate patterns immediately** - Fail fast on invalid input
3. **Allow defer option** - Users can collect some credentials later
4. **Check .gitignore** - Ensure .env is protected
5. **Support custom integrations** - Not everything is in the mapping
6. **Preserve existing .env** - Merge new credentials, don't overwrite
7. **Interactive confirmation** - Always confirm detected integrations
8. **Always collect purpose** - Ask what each integration is used for
9. **Store in database with encryption** - Use CredentialRepository for encrypted storage
10. **Dual storage** - Both .env file and database for flexibility

---

## Credential Collection Flow

```
┌─────────────────────────────────────────────────────────┐
│ Read 04_technical_architecture.md                       │
│ Extract integration mentions                            │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ Match against credential-mapping.json                   │
│ Build list of detected integrations                     │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ Interactive Confirmation                                │
│ User confirms/modifies/adds integrations                │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ Collect Purpose for Each Integration                    │
│ Ask: "What is {Integration} used for?"                  │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ For each integration:                                   │
│   - Look up required credentials                        │
│   - Prompt for each value (or accept default/defer)     │
│   - Validate against patterns                           │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ Generate .env and .env.template                         │
│ Update .gitignore if needed                             │
│ Validate .env not tracked                               │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ Store in Database (Encrypted)                           │
│   - IntegrationCredential with purpose                  │
│   - AES-256-GCM encryption for sensitive fields         │
│   - Link to scope_name                                  │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ Save credentials.yaml state                             │
│ Show summary with database storage status               │
└─────────────────────────────────────────────────────────┘
```

---

## Pattern Validation Examples

| Integration | Credential | Pattern | Valid Example |
|-------------|------------|---------|---------------|
| Stripe | STRIPE_SECRET_KEY | `^sk_(test\|live)_[a-zA-Z0-9]+$` | sk_test_abc123 |
| AWS | AWS_ACCESS_KEY_ID | `^[A-Z0-9]{20}$` | AKIAIOSFODNN7EXAMPLE |
| Twilio | TWILIO_ACCOUNT_SID | `^AC[a-zA-Z0-9]{32}$` | AC1234567890abcdef... |
| GitHub | GITHUB_TOKEN | `^(ghp\|gho\|ghu\|ghs\|ghr)_[a-zA-Z0-9]{36,251}$` | ghp_abc123... |
| MongoDB | MONGODB_URI | `^mongodb(\+srv)?://.+` | mongodb+srv://... |

If validation fails, show:
```
❌ Invalid format for {CREDENTIAL_NAME}
Expected pattern: {description}
Example: {example}
Please re-enter:
```
