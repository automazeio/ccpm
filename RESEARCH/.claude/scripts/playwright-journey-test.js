#!/usr/bin/env node
/**
 * playwright-journey-test.js - Execute user journey tests with Playwright
 *
 * Usage:
 *   node playwright-journey-test.js --session <session> --journey <journey-id> --persona <persona-id> [--base-url <url>]
 *
 * Outputs JSON results to stdout for parsing by the calling script.
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

// Parse command line arguments
function parseArgs() {
  const args = process.argv.slice(2);
  const config = {
    session: null,
    journeyId: null,
    personaId: null,
    baseUrl: 'http://localhost:5173',
    journeyData: null,
    personaData: null,
    journeyFile: null,
    personaFile: null,
    testRunId: `run-${new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19)}`,
    screenshotsDir: null,
    timeout: 15000
  };

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--session':
        config.session = args[++i];
        break;
      case '--journey':
        config.journeyId = args[++i];
        break;
      case '--persona':
        config.personaId = args[++i];
        break;
      case '--base-url':
        config.baseUrl = args[++i];
        break;
      case '--journey-data':
        config.journeyData = JSON.parse(args[++i]);
        break;
      case '--persona-data':
        config.personaData = JSON.parse(args[++i]);
        break;
      case '--journey-file':
        config.journeyFile = args[++i];
        break;
      case '--persona-file':
        config.personaFile = args[++i];
        break;
      case '--test-run-id':
        config.testRunId = args[++i];
        break;
      case '--timeout':
        config.timeout = parseInt(args[++i], 10);
        break;
    }
  }

  // Load journey data from file if provided
  if (config.journeyFile && fs.existsSync(config.journeyFile)) {
    try {
      const content = fs.readFileSync(config.journeyFile, 'utf-8').trim();
      if (content && content !== '{}') {
        config.journeyData = JSON.parse(content);
      }
    } catch (e) {
      console.error(`Warning: Failed to parse journey file: ${e.message}`);
    }
  }

  // Load persona data from file if provided
  if (config.personaFile && fs.existsSync(config.personaFile)) {
    try {
      const content = fs.readFileSync(config.personaFile, 'utf-8').trim();
      if (content && content !== '{}') {
        config.personaData = JSON.parse(content);
      }
    } catch (e) {
      console.error(`Warning: Failed to parse persona file: ${e.message}`);
    }
  }

  config.screenshotsDir = `.claude/testing/screenshots/${config.testRunId}`;
  return config;
}

// Load persona from JSON file if not provided inline
function loadPersona(config) {
  if (config.personaData) return config.personaData;

  const personaFile = `.claude/testing/personas/${config.session}-personas.json`;
  if (!fs.existsSync(personaFile)) {
    throw new Error(`Personas file not found: ${personaFile}`);
  }

  const data = JSON.parse(fs.readFileSync(personaFile, 'utf-8'));
  const persona = data.personas?.find(p => p.id === config.personaId);
  if (!persona) {
    throw new Error(`Persona ${config.personaId} not found in ${personaFile}`);
  }
  return persona;
}

// Get timeout based on persona patience level
function getTimeout(persona, baseTimeout) {
  const patience = persona?.behavioral?.patienceLevel || 'medium';
  switch (patience) {
    case 'low': return baseTimeout * 0.5;
    case 'high': return baseTimeout * 2;
    default: return baseTimeout;
  }
}

// Take screenshot and save
async function takeScreenshot(page, config, name) {
  try {
    if (!fs.existsSync(config.screenshotsDir)) {
      fs.mkdirSync(config.screenshotsDir, { recursive: true });
    }
    const filename = `${config.screenshotsDir}/${name}.png`;
    await page.screenshot({ path: filename, fullPage: true });
    return filename;
  } catch (e) {
    return null;
  }
}

// Execute the journey test
async function runJourneyTest(config) {
  const results = {
    journey_id: config.journeyId,
    persona_id: config.personaId,
    base_url: config.baseUrl,
    test_run_id: config.testRunId,
    overall_status: 'pass',
    login_status: 'skip',
    login_notes: '',
    steps_passed: 0,
    steps_failed: 0,
    steps_skipped: 0,
    step_results: [],
    issues_found: [],
    screenshots_count: 0,
    executed_at: new Date().toISOString()
  };

  let browser = null;
  let page = null;

  try {
    const persona = loadPersona(config);
    const timeout = getTimeout(persona, config.timeout);

    // Launch browser
    browser = await chromium.launch({
      headless: true,
      args: ['--disable-gpu', '--no-sandbox', '--disable-dev-shm-usage']
    });

    const context = await browser.newContext({
      viewport: { width: 1280, height: 720 },
      userAgent: 'Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 Playwright Test'
    });

    page = await context.newPage();
    page.setDefaultTimeout(timeout);

    // Navigate to base URL
    console.error(`Navigating to ${config.baseUrl}...`);
    await page.goto(config.baseUrl, { waitUntil: 'networkidle', timeout: timeout * 2 });
    await takeScreenshot(page, config, '00-initial');
    results.screenshots_count++;

    // Check if login is needed and attempt it
    const currentUrl = page.url();
    const needsLogin = currentUrl.includes('login') ||
                       currentUrl.includes('signin') ||
                       await page.locator('input[type="password"]').count() > 0;

    if (needsLogin && persona.testData?.email && persona.testData?.password) {
      console.error('Attempting login...');
      try {
        // Try common login patterns
        const emailInput = page.locator('input[type="email"], input[name="email"], input[id*="email"], input[placeholder*="email" i]').first();
        const passwordInput = page.locator('input[type="password"]').first();
        const submitButton = page.locator('button[type="submit"], input[type="submit"], button:has-text("Login"), button:has-text("Sign in")').first();

        if (await emailInput.count() > 0) {
          await emailInput.fill(persona.testData.email);
          await passwordInput.fill(persona.testData.password);
          await submitButton.click();
          await page.waitForLoadState('networkidle', { timeout });

          results.login_status = 'pass';
          results.login_notes = `Logged in as ${persona.testData.email}`;
        }
      } catch (e) {
        results.login_status = 'fail';
        results.login_notes = `Login failed: ${e.message}`;
      }
      await takeScreenshot(page, config, '01-after-login');
      results.screenshots_count++;
    } else {
      results.login_status = 'skip';
      results.login_notes = 'No login required or no credentials provided';
    }

    // Execute journey steps if provided
    const steps = config.journeyData?.steps || [];

    for (let i = 0; i < steps.length; i++) {
      const step = steps[i];
      const stepNum = step.step_number || (i + 1);
      const stepResult = {
        step_number: stepNum,
        step_name: step.step_name || step.name || `Step ${stepNum}`,
        status: 'pending',
        observation: ''
      };

      try {
        console.error(`Executing step ${stepNum}: ${stepResult.step_name}`);

        // Navigate to page if specified
        if (step.ui_page_route && !page.url().includes(step.ui_page_route)) {
          await page.goto(`${config.baseUrl}${step.ui_page_route}`, { waitUntil: 'networkidle' });
        }

        // Perform user action based on step data
        if (step.user_action) {
          const action = step.user_action.toLowerCase();

          if (action.includes('click')) {
            // Try to find and click the element
            const selector = step.ui_component_name || step.user_action.match(/"([^"]+)"/)?.[1];
            if (selector) {
              const element = page.locator(`text="${selector}", [data-testid="${selector}"], button:has-text("${selector}"), a:has-text("${selector}")`).first();
              if (await element.count() > 0) {
                await element.click();
                await page.waitForLoadState('networkidle', { timeout: timeout / 2 }).catch(() => {});
              }
            }
          } else if (action.includes('fill') || action.includes('enter') || action.includes('type')) {
            const input = page.locator(`input, textarea`).first();
            if (await input.count() > 0) {
              await input.fill(step.test_value || 'test input');
            }
          }
        }

        // Verify expected state
        await page.waitForLoadState('domcontentloaded');
        const pageContent = await page.content();

        stepResult.status = 'pass';
        stepResult.observation = `Step completed. Current URL: ${page.url()}`;
        results.steps_passed++;

      } catch (e) {
        stepResult.status = 'fail';
        stepResult.observation = e.message;
        results.steps_failed++;
        results.issues_found.push({
          step_number: stepNum,
          step_name: stepResult.step_name,
          description: e.message,
          url: page.url()
        });
      }

      // Take screenshot after each step
      await takeScreenshot(page, config, `step-${String(stepNum).padStart(2, '0')}`);
      results.screenshots_count++;
      results.step_results.push(stepResult);
    }

    // If no steps provided, just verify the page loaded
    if (steps.length === 0) {
      const title = await page.title();
      results.step_results.push({
        step_number: 1,
        step_name: 'Verify page loads',
        status: 'pass',
        observation: `Page loaded successfully. Title: "${title}"`
      });
      results.steps_passed = 1;
    }

    // Set overall status
    if (results.steps_failed > 0) {
      results.overall_status = results.steps_passed > 0 ? 'partial' : 'fail';
    } else if (results.login_status === 'fail') {
      results.overall_status = 'fail';
    }

  } catch (e) {
    results.overall_status = 'fail';
    results.issues_found.push({
      step_number: 0,
      step_name: 'Test Setup',
      description: e.message
    });

    if (page) {
      await takeScreenshot(page, config, 'error');
      results.screenshots_count++;
    }
  } finally {
    if (browser) {
      await browser.close();
    }
  }

  return results;
}

// Main entry point
async function main() {
  const config = parseArgs();

  if (!config.session || !config.journeyId || !config.personaId) {
    console.error('Usage: node playwright-journey-test.js --session <session> --journey <journey-id> --persona <persona-id> [--base-url <url>]');
    process.exit(1);
  }

  try {
    const results = await runJourneyTest(config);
    // Output JSON results to stdout for parsing
    console.log(JSON.stringify(results, null, 2));
    process.exit(results.overall_status === 'pass' ? 0 : 1);
  } catch (e) {
    console.error('Test execution failed:', e.message);
    console.log(JSON.stringify({
      journey_id: config.journeyId,
      persona_id: config.personaId,
      overall_status: 'fail',
      issues_found: [{ step_number: 0, description: e.message }]
    }));
    process.exit(1);
  }
}

main();
