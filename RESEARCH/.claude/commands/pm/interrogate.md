# Interrogate - Feature-Based Discovery Pipeline

Guide users through a streamlined discovery process: **deep research first**, then **single confirmation**, then **brief infrastructure questions**.

## Usage
```
/pm:interrogate [session-name]
```

## Arguments
- `session-name` (optional): Name for this session. Defaults to timestamp.

## Output

**Database tables populated:**
- `feature` - Features discovered from research
- `journey` - User journeys discovered from research
- `user_type` - User types and their expected counts
- `user_type_feature` - Feature access per user type
- `integration` - Third-party integrations
- `cross_cutting_concern` - Auth, deployment, scaling config

**File output:** `.claude/interrogations/{session-name}/conversation.md`

## Core Principle

**Research populates the database first. User confirms/modifies, not answers endless questions.**

---

## Flow Overview

```
1. User introduces topic
2. Run /dr-refine to clarify and narrow scope
3. Run /dr-full with refined question for features and journeys
4. Store researched features + journeys in database
5. Present ALL findings for single confirmation
6. Brief infrastructure questions (auth, scaling, permissions, deployment, integrations)
7. Auto-generate technical ops per journey step
8. Output: Confirmed Features → Confirmed Journeys → Technical Ops
```

---

## Instructions

### Step 1: Initialize Session

```bash
SESSION_NAME="${ARGUMENTS:-$(date +%Y%m%d-%H%M%S)}"
SESSION_DIR=".claude/interrogations/$SESSION_NAME"
mkdir -p "$SESSION_DIR"
CONV_FILE="$SESSION_DIR/conversation.md"
```

**Check if resuming:**

```bash
if [ -f "$CONV_FILE" ]; then
  echo "=== Resuming Session: $SESSION_NAME ==="
fi
```

If conversation.md exists and has content, read it and determine which step to resume from.

**If new session, initialize conversation.md:**

```markdown
# Interrogation: {session-name}

Started: {current datetime}
Status: in_progress
Phase: topic_input

---

## Conversation

```

---

### Step 2: Get Topic

Ask ONE question:

```
"What would you like to build?"
```

**Write to conversation.md immediately:**
```markdown
**Claude:** What would you like to build?

**User:** {their response}

```

Store the topic in a variable: `TOPIC="{user's response}"`

Update conversation.md phase:
```markdown
Phase: research
Topic: {TOPIC}
```

---

### Step 3: Refine Research Question

**Before running deep research, refine the topic with the user.**

Execute `/dr-refine` with the topic:

```
/dr-refine "Build a {TOPIC} application"
```

This will:
1. Ask 2-3 clarifying questions about the topic
2. Help narrow scope and identify key aspects
3. Generate a refined research question

**Record in conversation.md:**
```markdown
---

## Research Refinement

Topic: {TOPIC}
Refined question: {output from dr-refine}

---
```

**After dr-refine completes, proceed to Step 4.**

---

### Step 4: Deep Research

**Execute deep research with the refined question from dr-refine.**

```
Execute /dr-full with the refined prompt, structured as:

"For a {REFINED_TOPIC} application, identify:

1. KEY FEATURES (capabilities users need):
   - List 8-15 core features
   - For each: name, brief description, which user types need it

2. USER JOURNEYS (how users accomplish goals):
   - List 5-8 common user flows
   - For each: name, actor (user type), trigger, goal, key steps

Focus on what's typical for this type of application. Be specific and practical."
```

Wait for /dr-full to complete. The output will contain structured features and journeys.

**Record in conversation.md:**
```markdown
---

## Deep Research Results

{Paste the /dr output here}

---
```

---

### Step 5: Store in Database

Parse the /dr output and insert into database. For each feature found:

```sql
-- Use the upsert_feature function for each feature
SELECT upsert_feature(
  '{SESSION_NAME}',
  '{feature_name}',
  '{feature_description}',
  'research'
);
```

For each journey found:

```sql
-- Use the upsert_journey function for each journey
SELECT upsert_journey(
  '{SESSION_NAME}',
  '{journey_name}',
  '{actor}',
  '{trigger}',
  '{goal}',
  'research'
);
```

Link features to journeys:

```sql
INSERT INTO feature_journey (feature_id, journey_id, role)
SELECT f.id, j.id, 'primary'
FROM feature f, journey j
WHERE f.session_name = '{SESSION_NAME}'
  AND j.session_name = '{SESSION_NAME}'
  AND f.name = '{feature_name}'
  AND j.name = '{journey_name}'
ON CONFLICT DO NOTHING;
```

Update conversation.md phase:
```markdown
Phase: confirmation
Features stored: {count}
Journeys stored: {count}
```

---

### Step 6: Single Confirmation Phase

**Present EVERYTHING at once for user review:**

Query the database and format the presentation:

```sql
-- Get all features
SELECT feature_id, name, description FROM feature
WHERE session_name = '{SESSION_NAME}' AND status = 'pending'
ORDER BY feature_id;

-- Get all journeys
SELECT journey_id, name, actor, goal FROM journey
WHERE session_name = '{SESSION_NAME}' AND confirmation_status = 'pending'
ORDER BY journey_id;
```

**Present to user:**

```
Based on research, here's what I found for {TOPIC}:

## Features
1. [F-001] {name} - {description}
2. [F-002] {name} - {description}
3. [F-003] {name} - {description}
...

## User Journeys
1. [J-001] {name} (Actor: {actor})
   Goal: {goal}
2. [J-002] {name} (Actor: {actor})
   Goal: {goal}
...

Please review and tell me:
- Which features to KEEP (default all), REMOVE, or MODIFY?
- Which journeys to KEEP (default all), REMOVE, or MODIFY?
- Anything to ADD?

You can say "all good" to confirm everything, or list specific changes.
```

**Process user response:**

- If user says "all good", "looks good", "confirm all", etc.:
  - Mark all features as `confirmed`
  - Mark all journeys as `confirmed`

- If user specifies changes:
  - **REMOVE X**: `UPDATE feature SET status = 'removed' WHERE name LIKE '%X%'`
  - **MODIFY X to Y**: Update description or name
  - **ADD X**: `SELECT upsert_feature('{SESSION_NAME}', 'X', 'User-specified feature', 'user')`

**Record in conversation.md:**
```markdown
**Claude:** {the presentation above}

**User:** {their response}

**Claude:** Got it. {Summary of changes made}

```

Update database accordingly, then update phase:
```markdown
Phase: infrastructure
Features confirmed: {count}
Features removed: {count}
Journeys confirmed: {count}
```

---

### Step 7: Cross-Cutting Concerns (Brief)

Ask these quick infrastructure questions. These are selections, not deep interrogation.

**Present as a single block of questions:**

```
A few quick infrastructure questions:

1. **Authentication method?**
   - Email/password
   - Social login (Google, GitHub, etc.)
   - SSO/Enterprise (SAML, OIDC)
   - Magic link/passwordless
   - API key only

2. **Expected user scale?**
   - 100s of users
   - 1,000s of users
   - 10,000s+ of users

3. **User permissions model?**
   - Everyone has same access
   - Different roles with different permissions

4. **Deployment target?**
   - AWS
   - GCP
   - Vercel
   - Self-hosted / On-premise
   - Not sure yet

5. **Third-party integrations?** (select all that apply)
   - Payment: Stripe, PayPal
   - E-commerce: Shopify
   - Support: Gorgias, Zendesk, Intercom
   - CRM: Salesforce, HubSpot
   - Communication: Slack, Email (SendGrid/SES)
   - Social: Facebook, Twitter/X
   - Automation: Zapier
   - None / Not sure yet
```

**Process responses and store:**

```sql
-- Store authentication choice
INSERT INTO cross_cutting_concern (session_name, concern_type, config)
VALUES ('{SESSION_NAME}', 'authentication', '{"method": "{choice}"}')
ON CONFLICT (session_name, concern_type) DO UPDATE
SET config = EXCLUDED.config, updated_at = NOW();

-- Store scaling expectation
INSERT INTO cross_cutting_concern (session_name, concern_type, config)
VALUES ('{SESSION_NAME}', 'scaling', '{"expected_users": "{choice}"}')
ON CONFLICT (session_name, concern_type) DO UPDATE
SET config = EXCLUDED.config, updated_at = NOW();

-- Store deployment target
INSERT INTO cross_cutting_concern (session_name, concern_type, config)
VALUES ('{SESSION_NAME}', 'deployment', '{"target": "{choice}"}')
ON CONFLICT (session_name, concern_type) DO UPDATE
SET config = EXCLUDED.config, updated_at = NOW();
```

**If user selected "Different roles":**

```
What user types/roles do you need?
(e.g., Admin, Customer, Support Agent, Manager)
```

For each user type:
```sql
INSERT INTO user_type (session_name, name, description)
VALUES ('{SESSION_NAME}', '{name}', '{description}');

-- Link to features with appropriate access
INSERT INTO user_type_feature (user_type_id, feature_id, access_level)
SELECT ut.id, f.id, 'full'
FROM user_type ut, feature f
WHERE ut.session_name = '{SESSION_NAME}'
  AND f.session_name = '{SESSION_NAME}'
  AND ut.name = '{user_type}'
  AND f.status = 'confirmed';
```

**For each integration selected:**

```sql
INSERT INTO integration (session_name, platform, direction, purpose, status)
VALUES ('{SESSION_NAME}', '{platform}', 'bidirectional', '{inferred purpose}', 'confirmed');
```

**Record in conversation.md:**
```markdown
**Claude:** {infrastructure questions}

**User:** {their selections}

**Claude:** Noted. Configuration saved.

```

Update phase:
```markdown
Phase: technical_ops
Auth: {method}
Scale: {level}
Deployment: {target}
Integrations: {list}
```

---

### Step 8: Generate Technical Operations

For each confirmed journey, auto-generate technical operations per step.

Query journeys and steps:
```sql
SELECT j.journey_id, j.name, js.step_number, js.user_action
FROM journey j
JOIN journey_steps_detailed js ON j.id = js.journey_id
WHERE j.session_name = '{SESSION_NAME}'
  AND j.confirmation_status = 'confirmed'
ORDER BY j.journey_id, js.step_number;
```

For each step, populate technical columns:

```sql
UPDATE journey_steps_detailed
SET
  frontend_event_type = '{inferred from user_action}',
  api_operation_type = '{mutation/query}',
  api_operation_name = '{inferred name}',
  db_operation = '{create/read/update/delete}',
  db_tables_affected = '{inferred tables}'::jsonb
WHERE id = {step_id};
```

**If no journey steps exist yet, create them from journey descriptions:**

Parse the journey goal and steps from the /dr output, then:
```sql
INSERT INTO journey_steps_detailed (journey_id, step_number, step_name, user_action, db_operation)
VALUES ({journey_id}, {n}, '{step_name}', '{user_action}', '{operation}');
```

---

### Step 9: Close Session

Update conversation.md:
```markdown
---

Status: complete
Completed: {current datetime}

## Summary

- Features confirmed: {count}
- Journeys confirmed: {count}
- User types: {count}
- Integrations: {count}

## Next Steps

1. Extract scope document: `/pm:extract-findings {session-name}`
2. The extract command will read from the database and generate:
   - 00_scope_document.md
   - 01_features.md
   - 02_user_journeys.md
   - 03_technical_ops.md (NEW)
   - 04_nfr_requirements.md
   - 05_technical_architecture.md
   - 06_risk_assessment.md
   - 07_gap_analysis.md
   - 08_test_plan.md (NEW)
```

**Tell the user:**

```
✅ Interrogation complete: {session-name}

Summary:
- {N} features confirmed
- {N} user journeys confirmed
- {N} user types defined
- {N} integrations identified

Configuration:
- Auth: {method}
- Scale: {level}
- Deployment: {target}

All data stored in database. Next step:
  /pm:extract-findings {session-name}

This will generate your scope document and technical specifications.
```

---

## Resuming Sessions

If conversation.md exists when starting, check the `Phase:` header:

| Phase | Resume Action |
|-------|--------------|
| `topic_input` | Ask for topic |
| `refine` | Run /dr-refine to clarify |
| `research` | Run /dr-full with refined question |
| `confirmation` | Present features/journeys for confirmation |
| `infrastructure` | Ask infrastructure questions |
| `technical_ops` | Generate technical ops |
| `complete` | Tell user session is complete |

---

## Writing Rules

**CRITICAL: Write to conversation.md after EVERY exchange.**

Output file: `.claude/interrogations/{session-name}/conversation.md`

Format:
```markdown
**Claude:** {what you said}

**User:** {what they said}

```

---

## Important Rules

1. **Refine first** - Run /dr-refine before /dr-full to clarify scope
2. **Research populates** - /dr-full discovers features and journeys
3. **Single confirmation** - Present all features+journeys at once
4. **Brief questions** - Infrastructure questions are quick selections
5. **Store in database** - All data goes to database tables
6. **Record everything** - Every exchange goes to conversation.md
7. **Auto-generate tech ops** - Technical operations derived from journeys
8. **Trust defaults** - If user says "looks good", confirm everything

---

## Database Tables Used

| Table | Purpose |
|-------|---------|
| `feature` | Stores features with session_name and status |
| `journey` | Stores journeys with session_name and confirmation_status |
| `journey_steps_detailed` | Stores journey steps with technical operations |
| `user_type` | Stores user types for the session |
| `user_type_feature` | Maps user types to feature access |
| `integration` | Stores third-party integrations |
| `cross_cutting_concern` | Stores auth, deployment, scaling config |
| `feature_journey` | Maps features to journeys |

---

## Example Session

```
Claude: What would you like to build?

User: An e-commerce platform for selling handmade goods

Claude: Let me refine this topic to ensure we research the right aspects...

[/dr-refine asks clarifying questions]

Claude: A few quick questions to narrow scope:
- Is this a marketplace (multiple sellers) or single seller?
- Do sellers handle their own shipping or centralized?
- Any specific payment requirements?

User: Marketplace with multiple sellers, sellers handle shipping, just need Stripe

Claude: Great, running deep research on "multi-vendor handmade goods marketplace with seller-managed shipping"...

[/dr-full executes and returns features and journeys]

Claude: Based on research, here's what I found:

## Features
1. [F-001] Product Catalog - Browse and search handmade products
2. [F-002] Shopping Cart - Add/remove items, view totals
3. [F-003] Checkout - Complete purchase with shipping and payment
4. [F-004] User Registration - Create buyer/seller accounts
5. [F-005] Seller Dashboard - Manage products, orders, earnings
6. [F-006] Order Management - Track orders, update status
7. [F-007] Review System - Leave and view product reviews
8. [F-008] Messaging - Buyer-seller communication
...

## User Journeys
1. [J-001] Browse and Purchase (Actor: Buyer)
   Goal: Find and buy a handmade product
2. [J-002] List a Product (Actor: Seller)
   Goal: Add a new product for sale
3. [J-003] Manage Orders (Actor: Seller)
   Goal: Fulfill customer orders
...

Please review and tell me:
- Which to KEEP, REMOVE, or MODIFY?
- Anything to ADD?

User: All good, but add a Favorites/Wishlist feature

Claude: Got it. Added [F-009] Favorites/Wishlist. All features and journeys confirmed.

A few quick infrastructure questions:

1. Authentication method?
2. Expected user scale?
3. Permissions model?
4. Deployment target?
5. Third-party integrations?

User: Social login, 1000s of users, different roles (buyer/seller/admin), Vercel, Stripe

Claude: Noted. Configuration saved.

✅ Interrogation complete: ecommerce-handmade

Summary:
- 9 features confirmed
- 5 user journeys confirmed
- 3 user types defined (buyer, seller, admin)
- 1 integration identified (Stripe)

Next step:
  /pm:extract-findings ecommerce-handmade
```
