# Generate Personas - Create Synthetic Test Personas from Scope Document

Generate 10 diverse synthetic personas for E2E testing based on user journeys and personas from the scope document.

## Usage
```
/pm:generate-personas <session-name> [--count N]
```

## Arguments
- `session-name` (required): Name of the scoped session (from /pm:extract-findings)
- `--count N` (optional): Number of personas to generate (default: 10)

## Input
**Required:** `.claude/scopes/{session-name}/02_user_journeys.md`
**Optional:** `.claude/scopes/{session-name}/01_features.md`

## Output
**Database:** `persona` table (session_name, persona_id, name, role, demographics, behavioral, journeys, test_data, feedback_preferences, metadata)
**File:** `.claude/testing/personas/{session-name}-personas.json` (backup copy)

---

## Process

### Step 1: Initialize and Validate

```bash
SESSION_NAME="${ARGUMENTS%% *}"
COUNT="${ARGUMENTS#*--count }"
[ "$COUNT" = "$ARGUMENTS" ] && COUNT=10
SCOPE_DIR=".claude/scopes/$SESSION_NAME"
OUTPUT_DIR=".claude/testing/personas"
```

Verify scope exists:
```
If .claude/scopes/{session-name}/ doesn't exist:
❌ Scope not found: {session-name}

Run /pm:extract-findings {session-name} first
```

Create output directory:
```bash
mkdir -p "$OUTPUT_DIR"
```

Read:
- `$SCOPE_DIR/02_user_journeys.md`
- `$SCOPE_DIR/01_features.md` (if exists)

---

### Step 2: Extract User Types from Journeys

Parse `02_user_journeys.md` to identify:
- Actor types (e.g., "Accounts Payable Clerk", "Manager", "Admin")
- User goals mentioned in journeys
- Trigger events and entry points
- Journey complexity indicators

Build a list of unique user types:
```
USER_TYPES = [
  { type: "primary", role: "...", journeys: ["J-001", "J-002"] },
  { type: "secondary", role: "...", journeys: ["J-003"] },
  ...
]
```

---

### Step 3: Generate Persona Distribution

Distribute personas across user types:
```
Distribution for 10 personas:
- 3 primary user type (most common user)
- 3 secondary user type
- 2 admin/power users
- 2 edge cases (new user, infrequent user)

Tech proficiency distribution:
- 2 low (20%)
- 5 medium (50%)
- 3 high (30%)

Age diversity:
- 25-65 range, varied distribution

Feedback styles:
- 3 detailed
- 3 brief
- 2 frustrated
- 2 enthusiastic
```

---

### Step 4: Generate Each Persona

For each persona slot, generate using this template:

```markdown
Generate a synthetic persona for E2E testing.

**Context:**
- User type: {user_type.role}
- Primary journeys: {user_type.journeys}
- Tech proficiency requirement: {proficiency}
- Feedback style requirement: {style}

**User Journeys from Scope:**
{02_user_journeys.md relevant sections}

**Requirements:**
1. Create a realistic name and demographic profile
2. Define 3-5 specific goals aligned with their journeys
3. Define 2-4 pain points they likely experience
4. Describe their preferred workflow
5. List 2-3 common mistakes they might make
6. Generate realistic test data fixtures (email, profile, seed data)
7. Define likely complaints and praises based on personality

**Output JSON matching this schema:**
{persona_schema}
```

---

### Step 5: Persona Schema

Each persona follows this TypeScript interface:

```typescript
interface SyntheticPersona {
  id: string;                    // "persona-01", "persona-02"
  name: string;                  // "Sarah Chen"
  role: string;                  // "Accounts Payable Clerk"

  // Demographics
  demographics: {
    age: number;
    techProficiency: 'low' | 'medium' | 'high';
    industry: string;
    companySize: 'small' | 'medium' | 'enterprise';
    devicePreference: 'desktop' | 'mobile' | 'both';
    accessibilityNeeds: string[];
  };

  // Behavioral traits
  behavioral: {
    goals: string[];               // What they want to achieve
    painPoints: string[];          // Frustrations with current solutions
    preferredWorkflow: string;     // How they like to work
    patienceLevel: 'low' | 'medium' | 'high';
    errorTolerance: 'low' | 'medium' | 'high';
    commonMistakes: string[];      // Errors they might make
  };

  // Journey mapping
  journeys: {
    primary: string[];             // J-001, J-002 (main paths they take)
    secondary: string[];           // Optional journeys
    frequency: 'daily' | 'weekly' | 'monthly' | 'occasional';
    sessionDuration: 'short' | 'medium' | 'long';
  };

  // Test data fixtures
  testData: {
    email: string;                 // test+persona-01@example.com
    password: string;              // Generated test password
    profileData: {
      displayName: string;
      avatar?: string;
      preferences: Record<string, any>;
    };
    seedData: {
      [entity: string]: any[];     // e.g., invoices: [{...}, {...}]
    };
  };

  // Feedback generation
  feedback: {
    style: 'detailed' | 'brief' | 'frustrated' | 'enthusiastic';
    complaintThreshold: number;    // 1-10 score below which they complain
    praiseThreshold: number;       // 1-10 score above which they praise
    likelyComplaints: string[];    // Things they tend to complain about
    likelyPraises: string[];       // Things they tend to praise
    verbosity: 'minimal' | 'moderate' | 'verbose';
  };

  // Metadata
  metadata: {
    userType: 'primary' | 'secondary' | 'admin' | 'edge_case';
    generatedFrom: string;         // Journey IDs that informed this persona
    createdAt: string;             // ISO datetime
  };
}
```

---

### Step 6: Generate Test Data Fixtures

For each persona, generate realistic test data:

**Email pattern:**
```
test+{persona-id}@{session-name}.test.local
```

**Seed data based on role:**
```typescript
// Example for "Accounts Payable Clerk"
{
  "invoices": [
    { "id": "INV-001", "vendor": "Acme Corp", "amount": 1500.00, "status": "pending" },
    { "id": "INV-002", "vendor": "TechSupply", "amount": 3200.00, "status": "approved" }
  ],
  "vendors": [
    { "id": "V-001", "name": "Acme Corp", "category": "supplies" }
  ]
}
```

---

### Step 7: Validate Persona Coverage

Ensure personas cover:
- [ ] All user types mentioned in journeys
- [ ] All journey IDs have at least one persona
- [ ] Tech proficiency range (2 low, 5 medium, 3 high for 10 personas)
- [ ] Age diversity (25-65)
- [ ] Device preferences (desktop, mobile, both)
- [ ] Feedback style variety

If coverage gaps exist, adjust persona distribution.

---

### Step 8: Insert Personas into Database

**Primary storage is the database.** For each generated persona, insert into the `persona` table:

```bash
# Load database credentials from .env
source .env 2>/dev/null || true
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_DB="${POSTGRES_DB:-$(basename $(pwd))}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
```

For each persona, execute:
```sql
INSERT INTO persona (session_name, persona_id, name, role, demographics, behavioral, journeys, test_data, feedback_preferences, metadata)
VALUES (
  '{session-name}',
  '{persona.id}',
  '{persona.name}',
  '{persona.role}',
  '{persona.demographics as JSONB}',
  '{persona.behavioral as JSONB}',
  '{persona.journeys as JSONB}',
  '{persona.testData as JSONB}',
  '{persona.feedback as JSONB}',
  '{persona.metadata as JSONB}'
)
ON CONFLICT (session_name, persona_id)
DO UPDATE SET
  name = EXCLUDED.name,
  role = EXCLUDED.role,
  demographics = EXCLUDED.demographics,
  behavioral = EXCLUDED.behavioral,
  journeys = EXCLUDED.journeys,
  test_data = EXCLUDED.test_data,
  feedback_preferences = EXCLUDED.feedback_preferences,
  metadata = EXCLUDED.metadata;
```

**Also write backup JSON file** to `.claude/testing/personas/{session-name}-personas.json`:

```json
{
  "session": "{session-name}",
  "generatedAt": "{ISO datetime}",
  "count": 10,
  "source": {
    "journeys": ".claude/scopes/{session-name}/02_user_journeys.md",
    "features": ".claude/scopes/{session-name}/01_features.md"
  },
  "coverage": {
    "userTypes": ["primary", "secondary", "admin", "edge_case"],
    "journeys": ["J-001", "J-002", "J-003"],
    "techProficiency": { "low": 2, "medium": 5, "high": 3 }
  },
  "personas": [
    { /* Persona 1 */ },
    { /* Persona 2 */ },
    ...
  ]
}
```

---

### Step 9: Present Summary

```
✅ Personas generated: {session-name}

Count: {count} personas

Distribution:
| Type | Count | Journeys Covered |
|------|-------|------------------|
| Primary | 3 | J-001, J-002 |
| Secondary | 3 | J-003, J-004 |
| Admin | 2 | J-005 |
| Edge Case | 2 | J-001, J-002 |

Tech Proficiency:
- Low: 2 (20%)
- Medium: 5 (50%)
- High: 3 (30%)

Feedback Styles:
- Detailed: 3
- Brief: 3
- Frustrated: 2
- Enthusiastic: 2

Journey Coverage: 100% ({N}/{N} journeys)

Storage:
- Database: {count} rows in `persona` table (session: {session-name})
- Backup: .claude/testing/personas/{session-name}-personas.json

Next Steps:
1. Review personas: psql -c "SELECT persona_id, name, role FROM persona WHERE session_name='{session-name}'"
2. Run pipeline: ./feedback-pipeline.sh {session-name}
3. Or generate tests: /pm:generate-tests {session-name}
```

---

## Example Persona

```json
{
  "id": "persona-01",
  "name": "Sarah Chen",
  "role": "Accounts Payable Clerk",
  "demographics": {
    "age": 34,
    "techProficiency": "medium",
    "industry": "Manufacturing",
    "companySize": "medium",
    "devicePreference": "desktop",
    "accessibilityNeeds": []
  },
  "behavioral": {
    "goals": [
      "Process invoices quickly and accurately",
      "Avoid duplicate payments",
      "Keep audit trail for compliance"
    ],
    "painPoints": [
      "Manual data entry errors",
      "Slow approval workflows",
      "Difficulty tracking invoice status"
    ],
    "preferredWorkflow": "Batch process invoices in morning, follow up on approvals in afternoon",
    "patienceLevel": "medium",
    "errorTolerance": "low",
    "commonMistakes": [
      "Entering wrong vendor for similar names",
      "Missing attachments on rush invoices"
    ]
  },
  "journeys": {
    "primary": ["J-001", "J-002"],
    "secondary": ["J-005"],
    "frequency": "daily",
    "sessionDuration": "long"
  },
  "testData": {
    "email": "test+persona-01@invoice-system.test.local",
    "password": "Test123!Persona01",
    "profileData": {
      "displayName": "Sarah Chen",
      "preferences": {
        "theme": "light",
        "notifications": true,
        "defaultView": "list"
      }
    },
    "seedData": {
      "invoices": [
        { "id": "INV-001", "vendor": "Acme Corp", "amount": 1500.00, "status": "pending" },
        { "id": "INV-002", "vendor": "TechSupply", "amount": 3200.00, "status": "approved" }
      ],
      "vendors": [
        { "id": "V-001", "name": "Acme Corp", "category": "supplies" },
        { "id": "V-002", "name": "TechSupply", "category": "equipment" }
      ]
    }
  },
  "feedback": {
    "style": "detailed",
    "complaintThreshold": 4,
    "praiseThreshold": 8,
    "likelyComplaints": [
      "Form validation is confusing",
      "Too many clicks to complete task",
      "Search doesn't find what I need"
    ],
    "likelyPraises": [
      "Clean interface",
      "Fast load times",
      "Good keyboard shortcuts"
    ],
    "verbosity": "moderate"
  },
  "metadata": {
    "userType": "primary",
    "generatedFrom": "J-001, J-002",
    "createdAt": "2026-01-14T12:00:00Z"
  }
}
```

---

## Important Rules

1. **Interview-style personas** - Include behavioral details, not just demographics
2. **Journey alignment** - Every persona must map to at least one journey
3. **Diversity** - Vary age, tech proficiency, patience, device preference
4. **Realistic test data** - Generate domain-appropriate seed data
5. **Feedback personality** - Each persona has distinct feedback tendencies
6. **Idempotent** - Running again overwrites with fresh personas

---

## Sources

Based on research from:
- Nielsen Norman Group: AI-Simulated Behavior Studies
- Synthetic Users Platform patterns
- Playwright parameterized testing best practices
