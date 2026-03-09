# Integration List

List all configured integrations and their status.

## Usage
```
/pm:integration-list [--available]
```

## Options
- `--available`: Show all available services in registry, not just configured ones

## Instructions

### Step 1: Load Registry

Get all available services from `.claude/integrations/registry/`:

```bash
for file in .claude/integrations/registry/*.yaml; do
  # Parse service ID from filename
  SERVICE_ID=$(basename "$file" .yaml)
  # Read service name and category from file
done
```

### Step 2: Check Configured Services

For each service, check if credentials exist in `.env`:

```bash
ENV_FILE="${WORK_DIR:-.}/.env"

for service in $SERVICES; do
  # Load service definition
  # Check if any credential names appear in .env
  # If found, mark as configured
done
```

### Step 3: Display Results

#### Configured Integrations Only (default)
```
📦 Configured Integrations

| Service | Category | Credentials |
|---------|----------|-------------|
| SendGrid | email | SENDGRID_API_KEY |
| Stripe | payments | STRIPE_SECRET_KEY, STRIPE_PUBLISHABLE_KEY |
| OpenAI | ai | OPENAI_API_KEY |

3 integrations configured

To verify credentials:
  /pm:integration-verify

To add more:
  /pm:integration-setup <service>
```

#### All Available (--available flag)
```
📦 Integration Registry

Category: AI/LLM
  ✅ openai - OpenAI (GPT models)
  ⬜ anthropic - Anthropic (Claude models)

Category: Email
  ✅ sendgrid - SendGrid (email delivery)
  ⬜ resend - Resend (email delivery)

Category: Payments
  ✅ stripe - Stripe (payment processing)
  ⬜ lemonsqueezy - LemonSqueezy (SaaS billing)

Category: Authentication
  ⬜ clerk - Clerk (auth + user management)
  ⬜ auth0 - Auth0 (enterprise auth)

Category: Vector Database
  ⬜ pinecone - Pinecone (vector search)
  ⬜ qdrant - Qdrant (vector search)

Category: Database
  ⬜ supabase - Supabase (Postgres + Auth + Storage)

Category: Storage
  ⬜ cloudflare-r2 - Cloudflare R2 (S3-compatible)

Category: Search
  ⬜ algolia - Algolia (search engine)

Category: SMS
  ⬜ twilio - Twilio (SMS + voice)

Category: Analytics
  ⬜ posthog - PostHog (product analytics)

Category: Monitoring
  ⬜ sentry - Sentry (error tracking)

Category: Cache
  ⬜ upstash - Upstash (serverless Redis)

Legend: ✅ Configured | ⬜ Available

To set up: /pm:integration-setup <service>
```

#### No Integrations Configured
```
No integrations configured.

Available services:
  - openai, anthropic (AI/LLM)
  - sendgrid, resend (Email)
  - stripe (Payments)
  - clerk, auth0 (Auth)
  - pinecone, qdrant (Vector DB)
  - supabase (Database)
  - cloudflare-r2 (Storage)
  - algolia (Search)
  - twilio (SMS)
  - posthog (Analytics)
  - sentry (Monitoring)
  - upstash (Cache)

To set up: /pm:integration-setup <service>
```

---

## Output Format

### Default (configured only)
```
📦 Configured Integrations

{N} integrations configured:
  - {service}: {credentials}
  ...

Commands:
  - Verify: /pm:integration-verify
  - Add: /pm:integration-setup <service>
```

### With --available
```
📦 Integration Registry

{category}:
  {status} {service} - {description}
  ...

Legend: ✅ Configured | ⬜ Available
```

---

## Integration Categories

| Category | Services |
|----------|----------|
| ai | openai, anthropic |
| email | sendgrid, resend |
| payments | stripe, lemonsqueezy |
| auth | clerk, auth0, workos |
| vector_db | pinecone, qdrant, weaviate |
| database | supabase, planetscale, neon |
| storage | cloudflare-r2, s3 |
| search | algolia, meilisearch |
| sms | twilio |
| analytics | posthog, amplitude |
| monitoring | sentry, datadog |
| cache | upstash, redis |
