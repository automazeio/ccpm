# Generate Tests - Create Playwright E2E Tests from Journeys and Personas

Generate a Playwright test suite with persona-aware Page Object Model and journey-based test scenarios.

## Usage
```
/pm:generate-tests <session-name>
```

## Arguments
- `session-name` (required): Name of the scoped session

## Input
**Required:**
- `.claude/scopes/{session-name}/02_user_journeys.md`
- `.claude/testing/personas/{session-name}-personas.json`

**Optional:**
- `.claude/scopes/{session-name}/01_features.md`

## Output
**Directory:** `.claude/testing/playwright/`
- `playwright.config.ts` - Multi-persona project configuration
- `fixtures/persona.fixture.ts` - Persona loading and data seeding
- `page-objects/*.page.ts` - Page Object Model classes
- `journeys/*.spec.ts` - Journey-based test files

---

## Process

### Step 1: Initialize and Validate

```bash
SESSION_NAME="$ARGUMENTS"
SCOPE_DIR=".claude/scopes/$SESSION_NAME"
PERSONAS_FILE=".claude/testing/personas/$SESSION_NAME-personas.json"
OUTPUT_DIR=".claude/testing/playwright"
```

Verify inputs exist:
```
If personas file doesn't exist:
❌ Personas not found: {personas-file}

Run /pm:generate-personas {session-name} first
```

Read:
- `$SCOPE_DIR/02_user_journeys.md`
- `$PERSONAS_FILE`

---

### Step 2: Generate Playwright Config

Create `playwright.config.ts` with persona-based projects:

```typescript
import { defineConfig, devices } from '@playwright/test';
import personas from './personas/{session-name}-personas.json';

export default defineConfig({
  testDir: './journeys',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html'],
    ['json', { outputFile: 'test-results.json' }]
  ],
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  // Generate a project for each persona
  projects: personas.personas.map((persona: any) => ({
    name: persona.id,
    use: {
      ...devices[persona.demographics.devicePreference === 'mobile' ? 'Pixel 5' : 'Desktop Chrome'],
      personaId: persona.id,
      // Adjust timeout based on patience level
      actionTimeout: persona.behavioral.patienceLevel === 'low' ? 5000 :
                     persona.behavioral.patienceLevel === 'medium' ? 15000 : 30000,
    },
    metadata: {
      persona: persona,
    },
  })),

  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
});
```

---

### Step 3: Generate Persona Fixture

Create `fixtures/persona.fixture.ts`:

```typescript
import { test as base, expect } from '@playwright/test';
import personas from '../personas/{session-name}-personas.json';

// Types
interface SyntheticPersona {
  id: string;
  name: string;
  role: string;
  demographics: {
    age: number;
    techProficiency: 'low' | 'medium' | 'high';
    industry: string;
    companySize: 'small' | 'medium' | 'enterprise';
    devicePreference: 'desktop' | 'mobile' | 'both';
    accessibilityNeeds: string[];
  };
  behavioral: {
    goals: string[];
    painPoints: string[];
    preferredWorkflow: string;
    patienceLevel: 'low' | 'medium' | 'high';
    errorTolerance: 'low' | 'medium' | 'high';
    commonMistakes: string[];
  };
  journeys: {
    primary: string[];
    secondary: string[];
    frequency: string;
    sessionDuration: string;
  };
  testData: {
    email: string;
    password: string;
    profileData: Record<string, any>;
    seedData: Record<string, any[]>;
  };
  feedback: {
    style: string;
    complaintThreshold: number;
    praiseThreshold: number;
    likelyComplaints: string[];
    likelyPraises: string[];
    verbosity: string;
  };
}

// Fixture types
type PersonaFixtures = {
  persona: SyntheticPersona;
  seedTestData: () => Promise<void>;
  cleanupTestData: () => Promise<void>;
  simulateTyping: (locator: any, text: string) => Promise<void>;
};

// API client for seeding (customize for your backend)
const api = {
  async createUser(email: string, password: string, profileData: any): Promise<void> {
    // TODO: Implement API call to create test user
    // await fetch(`${process.env.API_URL}/test/users`, {
    //   method: 'POST',
    //   body: JSON.stringify({ email, password, ...profileData })
    // });
  },

  async seedData(entity: string, records: any[]): Promise<void> {
    // TODO: Implement API call to seed test data
    // await fetch(`${process.env.API_URL}/test/seed/${entity}`, {
    //   method: 'POST',
    //   body: JSON.stringify(records)
    // });
  },

  async cleanup(email: string): Promise<void> {
    // TODO: Implement API call to cleanup test data
    // await fetch(`${process.env.API_URL}/test/cleanup`, {
    //   method: 'POST',
    //   body: JSON.stringify({ email })
    // });
  }
};

// Extend base test with persona fixtures
export const test = base.extend<PersonaFixtures>({
  // Load persona based on project configuration
  persona: async ({}, use, testInfo) => {
    const personaId = (testInfo.project.use as any).personaId || 'persona-01';
    const persona = personas.personas.find((p: any) => p.id === personaId);

    if (!persona) {
      throw new Error(`Persona not found: ${personaId}`);
    }

    await use(persona as SyntheticPersona);
  },

  // Seed test data for persona
  seedTestData: async ({ persona }, use) => {
    const seed = async () => {
      // Create user account
      await api.createUser(
        persona.testData.email,
        persona.testData.password,
        persona.testData.profileData
      );

      // Seed persona-specific data
      for (const [entity, records] of Object.entries(persona.testData.seedData)) {
        await api.seedData(entity, records);
      }
    };

    await use(seed);
  },

  // Cleanup after test
  cleanupTestData: async ({ persona }, use) => {
    const cleanup = async () => {
      await api.cleanup(persona.testData.email);
    };

    await use(cleanup);
  },

  // Simulate typing based on tech proficiency
  simulateTyping: async ({ page, persona }, use) => {
    const typeWithDelay = async (locator: any, text: string) => {
      // Low tech proficiency = slower typing
      const delay = persona.demographics.techProficiency === 'low' ? 150 :
                    persona.demographics.techProficiency === 'medium' ? 50 : 0;

      if (delay > 0) {
        await locator.type(text, { delay });
      } else {
        await locator.fill(text);
      }
    };

    await use(typeWithDelay);
  },
});

export { expect };

// Helper to get timeout based on persona patience
export function getTimeout(persona: SyntheticPersona): number {
  return persona.behavioral.patienceLevel === 'low' ? 5000 :
         persona.behavioral.patienceLevel === 'medium' ? 15000 : 30000;
}

// Helper to check if persona would notice an issue
export function wouldNotice(persona: SyntheticPersona, issueType: string): boolean {
  const techIssues = ['performance', 'keyboard-shortcut', 'api-error'];
  const uxIssues = ['layout', 'color', 'spacing'];

  if (techIssues.includes(issueType)) {
    return persona.demographics.techProficiency !== 'low';
  }

  return true;
}
```

---

### Step 4: Generate Page Objects

For each unique page/component in journeys, create a Page Object:

**Base Page (`page-objects/base.page.ts`):**
```typescript
import { Page, Locator } from '@playwright/test';

export abstract class BasePage {
  readonly page: Page;
  readonly persona: any;

  constructor(page: Page, persona?: any) {
    this.page = page;
    this.persona = persona;
  }

  // Common navigation
  async goto(path: string): Promise<void> {
    await this.page.goto(path);
  }

  // Wait with persona-aware timeout
  async waitForElement(locator: Locator): Promise<void> {
    const timeout = this.persona?.behavioral?.patienceLevel === 'low' ? 5000 :
                    this.persona?.behavioral?.patienceLevel === 'medium' ? 15000 : 30000;
    await locator.waitFor({ timeout });
  }

  // Type with persona-aware delay
  async typeWithPersonaSpeed(locator: Locator, text: string): Promise<void> {
    const delay = this.persona?.demographics?.techProficiency === 'low' ? 150 :
                  this.persona?.demographics?.techProficiency === 'medium' ? 50 : 0;

    if (delay > 0) {
      await locator.type(text, { delay });
    } else {
      await locator.fill(text);
    }
  }
}
```

**Login Page (`page-objects/login.page.ts`):**
```typescript
import { Page, Locator, expect } from '@playwright/test';
import { BasePage } from './base.page';

export class LoginPage extends BasePage {
  // Locators
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly errorMessage: Locator;

  constructor(page: Page, persona?: any) {
    super(page, persona);
    this.emailInput = page.getByLabel('Email');
    this.passwordInput = page.getByLabel('Password');
    this.submitButton = page.getByRole('button', { name: 'Sign in' });
    this.errorMessage = page.getByRole('alert');
  }

  async goto(): Promise<void> {
    await super.goto('/login');
  }

  async login(email?: string, password?: string): Promise<void> {
    const userEmail = email || this.persona?.testData?.email;
    const userPassword = password || this.persona?.testData?.password;

    await this.typeWithPersonaSpeed(this.emailInput, userEmail);
    await this.typeWithPersonaSpeed(this.passwordInput, userPassword);
    await this.submitButton.click();
  }

  async expectLoginSuccess(): Promise<void> {
    await expect(this.page).toHaveURL(/.*dashboard/);
  }

  async expectLoginError(message?: string): Promise<void> {
    await expect(this.errorMessage).toBeVisible();
    if (message) {
      await expect(this.errorMessage).toContainText(message);
    }
  }
}
```

---

### Step 5: Generate Journey Tests

For each journey in `02_user_journeys.md`, create a test file:

**Journey Test Template (`journeys/J-{XXX}-{name}.spec.ts`):**
```typescript
import { test, expect } from '../fixtures/persona.fixture';
import { LoginPage } from '../page-objects/login.page';
// Import other page objects as needed

test.describe('J-{XXX}: {Journey Name}', () => {
  test.beforeEach(async ({ page, persona, seedTestData }) => {
    // Seed test data for this persona
    await seedTestData();

    // Login as persona
    const loginPage = new LoginPage(page, persona);
    await loginPage.goto();
    await loginPage.login();
    await loginPage.expectLoginSuccess();
  });

  test.afterEach(async ({ cleanupTestData }) => {
    await cleanupTestData();
  });

  test('complete {journey name} flow', async ({ page, persona }) => {
    // Step 1: {First step from journey}
    await test.step('{Step 1 name}', async () => {
      // Implementation based on journey step
    });

    // Step 2: {Second step from journey}
    await test.step('{Step 2 name}', async () => {
      // Implementation based on journey step
    });

    // Continue for all steps...
  });

  // Test persona-specific edge cases
  test('handles errors for {persona role}', async ({ page, persona }) => {
    // Test common mistakes this persona might make
    for (const mistake of persona.behavioral.commonMistakes) {
      await test.step(`Handle: ${mistake}`, async () => {
        // Test error handling
      });
    }
  });
});
```

---

### Step 6: Generate Test File Mapping

Create a mapping file to track journey-to-test correspondence:

**`journey-test-map.json`:**
```json
{
  "session": "{session-name}",
  "generatedAt": "{ISO datetime}",
  "journeys": {
    "J-001": {
      "file": "journeys/J-001-create-invoice.spec.ts",
      "steps": 5,
      "personas": ["persona-01", "persona-02", "persona-05"],
      "pageObjects": ["login.page.ts", "invoice.page.ts"]
    },
    "J-002": {
      "file": "journeys/J-002-approve-invoice.spec.ts",
      "steps": 3,
      "personas": ["persona-03", "persona-04"],
      "pageObjects": ["login.page.ts", "approval.page.ts"]
    }
  }
}
```

---

### Step 7: Present Summary

```
✅ Playwright tests generated: {session-name}

Files Created:
├── playwright.config.ts          (10 persona projects)
├── fixtures/
│   └── persona.fixture.ts        (persona loading + seeding)
├── page-objects/
│   ├── base.page.ts
│   ├── login.page.ts
│   └── {N} more page objects
└── journeys/
    └── {N} journey test files

Journey Coverage:
| Journey | Test File | Steps | Personas |
|---------|-----------|-------|----------|
| J-001 | J-001-create-invoice.spec.ts | 5 | 3 |
| J-002 | J-002-approve-invoice.spec.ts | 3 | 2 |

Output: .claude/testing/playwright/

Next Steps:
1. Install Playwright: cd .claude/testing/playwright && npm init -y && npm i -D @playwright/test
2. Run tests: npx playwright test
3. Generate feedback: /pm:generate-feedback {session-name}
```

---

## Important Rules

1. **Page Object Model** - All interactions through page objects
2. **Persona awareness** - Tests adapt to persona characteristics
3. **Step isolation** - Use `test.step()` for journey steps
4. **Data cleanup** - Always cleanup test data after tests
5. **Timeout variance** - Adjust timeouts based on persona patience
6. **Error testing** - Include tests for common persona mistakes

---

## Sources

Based on research from:
- Playwright fixture documentation
- Page Object Model best practices
- Data-driven testing patterns
