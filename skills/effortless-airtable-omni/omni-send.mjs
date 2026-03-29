#!/usr/bin/env node
/**
 * omni-send.mjs — Drive Airtable's OMNI AI via Playwright
 *
 * Usage:
 *   node omni-send.mjs <baseId> <prompt>          Send a prompt to OMNI
 *   node omni-send.mjs <baseId> --login           Open browser for login only
 *   node omni-send.mjs <baseId> --screenshot      Take a screenshot of the current state
 *
 * The base ID can be found in effortless.json:
 *   cat effortless.json | jq -r '.ProjectSettings[] | select(.Name == "baseId") | .Value'
 *
 * On first run, the user must log in manually — the persistent browser profile
 * at /tmp/airtable-omni-profile retains the session for subsequent runs.
 *
 * Exit codes:
 *   0 — success (response printed to stdout)
 *   1 — error (message on stderr)
 *   2 — login required (browser left open for user)
 */

import { chromium } from 'playwright';
import { existsSync, readFileSync } from 'fs';
import { resolve, dirname } from 'path';

const PROFILE_DIR = '/tmp/airtable-omni-profile';
const SCREENSHOT_DIR = process.cwd();

// ---------------------------------------------------------------------------
// Parse args
// ---------------------------------------------------------------------------
const args = process.argv.slice(2);
if (args.length < 2) {
  console.error('Usage: node omni-send.mjs <baseId> <prompt | --login | --screenshot>');
  process.exit(1);
}

const baseId = args[0];
const mode = args[1] === '--login' ? 'login'
           : args[1] === '--screenshot' ? 'screenshot'
           : 'prompt';
const prompt = mode === 'prompt' ? args.slice(1).join(' ') : null;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function findBySelectors(page, selectors, label) {
  for (const sel of selectors) {
    try {
      const el = page.locator(sel).first();
      if (await el.isVisible({ timeout: 1500 })) {
        console.error(`  [${label}] found via: ${sel}`);
        return el;
      }
    } catch { /* try next */ }
  }
  return null;
}

async function dumpDebugInfo(page, screenshotName) {
  const screenshotPath = resolve(SCREENSHOT_DIR, screenshotName);
  await page.screenshot({ path: screenshotPath, fullPage: false });
  console.error(`Screenshot saved to ${screenshotPath}`);

  console.error('Visible buttons:');
  const buttons = await page.locator('button').all();
  for (const btn of buttons.slice(0, 30)) {
    const text = (await btn.textContent().catch(() => '')).trim();
    const label = await btn.getAttribute('aria-label').catch(() => '') || '';
    const box = await btn.boundingBox().catch(() => null);
    if (text || label) {
      console.error(`  button: text="${text.substring(0, 50)}" aria-label="${label}" visible=${!!box}`);
    }
  }
}

async function waitForOmniResponse(page, timeoutSeconds = 60) {
  let lastContent = '';
  let stableCount = 0;

  for (let i = 0; i < timeoutSeconds; i++) {
    await page.waitForTimeout(1000);

    // Check for confirmation button and click it
    try {
      const confirmBtn = page.locator('button:has-text("Yes,")').first();
      if (await confirmBtn.isVisible({ timeout: 300 })) {
        console.error('  Clicking confirmation button...');
        await confirmBtn.click();
        stableCount = 0;
        continue;
      }
    } catch { /* no confirmation needed */ }

    // Poll for content stability
    try {
      const messages = await page.locator('[class*="message"], [class*="response"], [class*="chat"], [data-testid*="message"]').allTextContents();
      const joined = messages.join('\n');
      if (joined === lastContent && joined.length > 0) {
        if (++stableCount >= 3) {
          console.error('  Response complete (stable for 3s).');
          return lastContent;
        }
      } else {
        stableCount = 0;
        lastContent = joined;
      }
    } catch { /* keep waiting */ }

    if (i % 10 === 9) {
      console.error(`  Waiting for OMNI... (${i + 1}s)`);
    }
  }

  // Timeout — return whatever we have
  console.error('  Response wait timed out — returning best-effort content.');
  return lastContent || null;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  console.error(`=== omni-send ===`);
  console.error(`Base: ${baseId}`);
  console.error(`Mode: ${mode}`);
  if (prompt) console.error(`Prompt: ${prompt}`);
  console.error('');

  const context = await chromium.launchPersistentContext(PROFILE_DIR, {
    headless: false,
    viewport: { width: 1400, height: 900 },
    args: ['--disable-blink-features=AutomationControlled'],
  });

  const page = context.pages()[0] || await context.newPage();

  // Navigate to the base
  console.error('Navigating to base...');
  await page.goto(`https://airtable.com/${baseId}`, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(5000);

  const url = page.url();
  console.error(`URL: ${url}`);

  // Login check
  if (url.includes('login') || url.includes('auth')) {
    if (mode === 'login') {
      console.error('');
      console.error('Please log in to Airtable in the browser window.');
      console.error('The browser will stay open — press Ctrl+C when done.');
      await new Promise(() => {});
    }
    console.error('ERROR: Not logged in. Run with --login first:');
    console.error(`  node omni-send.mjs ${baseId} --login`);
    await context.close();
    process.exit(2);
  }

  // --- Login-only mode ---
  if (mode === 'login') {
    console.error('Already logged in. Session is valid.');
    console.stdout?.write?.('LOGGED_IN\n') || process.stdout.write('LOGGED_IN\n');
    await context.close();
    process.exit(0);
  }

  // --- Screenshot-only mode ---
  if (mode === 'screenshot') {
    const path = resolve(SCREENSHOT_DIR, 'airtable-screenshot.png');
    await page.screenshot({ path, fullPage: false });
    process.stdout.write(`${path}\n`);
    await context.close();
    process.exit(0);
  }

  // --- Prompt mode ---
  await page.waitForTimeout(2000);

  // Step 1: Find and open OMNI
  console.error('Opening OMNI...');
  const omniButton = await findBySelectors(page, [
    '[aria-label*="Omni"]',
    '[aria-label*="AI"]',
    'button:has-text("Back to Omni")',
    'button:has-text("Omni")',
    'button:has-text("Ask AI")',
    'button:has-text("AI")',
    '[data-testid*="omni"]',
    '[data-testid*="ai"]',
  ], 'OMNI button');

  if (!omniButton) {
    console.error('ERROR: Could not find OMNI button.');
    await dumpDebugInfo(page, 'omni-debug-button.png');
    await context.close();
    process.exit(1);
  }

  await omniButton.click();
  console.error('  Waiting for OMNI panel to open (10s)...');
  await page.waitForTimeout(10000);

  // After clicking OMNI, we may land on a sub-panel. Check for "Back to Omni" and click it.
  const backToOmni = await findBySelectors(page, [
    'button:has-text("Back to Omni")',
  ], 'Back to Omni');
  if (backToOmni) {
    console.error('  Found sub-panel, clicking Back to Omni...');
    await backToOmni.click();
    await page.waitForTimeout(3000);
  }

  // Step 2: Find input and send prompt
  console.error('Finding input...');

  // Debug: take a screenshot to see what panel is open
  await page.screenshot({ path: resolve(SCREENSHOT_DIR, 'omni-debug-after-click.png'), fullPage: false });
  console.error('  Debug screenshot saved: omni-debug-after-click.png');

  // Also dump all inputs/textareas for debugging
  const allInputs = await page.locator('textarea, input, [contenteditable="true"], [role="textbox"]').all();
  console.error(`  Found ${allInputs.length} input elements:`);
  for (const inp of allInputs.slice(0, 15)) {
    const tag = await inp.evaluate(el => el.tagName).catch(() => '?');
    const ph = await inp.getAttribute('placeholder').catch(() => '') || '';
    const role = await inp.getAttribute('role').catch(() => '') || '';
    const box = await inp.boundingBox().catch(() => null);
    console.error(`    ${tag} placeholder="${ph}" role="${role}" visible=${!!box}`);
  }

  const omniInput = await findBySelectors(page, [
    'textarea[placeholder*="Ask me anything"]',
    'textarea[placeholder*="Ask"]',
    'textarea[placeholder*="ask"]',
    '[placeholder*="Ask me anything"]',
    'input[placeholder*="Ask me anything"]',
    '[role="textbox"]',
    '[contenteditable="true"]',
    'textarea',
  ], 'OMNI input');

  if (!omniInput) {
    console.error('ERROR: Could not find OMNI input.');
    await dumpDebugInfo(page, 'omni-debug-input.png');
    await context.close();
    process.exit(1);
  }

  console.error('Sending prompt...');
  await omniInput.click();
  await omniInput.fill(prompt);
  await page.waitForTimeout(500);
  await page.keyboard.press('Enter');

  // Step 3: Wait for response
  console.error('Waiting for response...');
  const response = await waitForOmniResponse(page);

  // Screenshot the result
  const screenshotPath = resolve(SCREENSHOT_DIR, 'omni-result.png');
  await page.screenshot({ path: screenshotPath, fullPage: false });
  console.error(`Screenshot: ${screenshotPath}`);

  // Output response to stdout (this is what Claude reads)
  if (response) {
    process.stdout.write(response + '\n');
  } else {
    process.stdout.write('(no response extracted)\n');
  }

  // Leave browser open for inspection
  console.error('');
  console.error('Browser left open for inspection. Press Ctrl+C to exit.');
  await new Promise(() => {});
}

main().catch(err => {
  console.error(`Error: ${err.message}`);
  process.exit(1);
});
