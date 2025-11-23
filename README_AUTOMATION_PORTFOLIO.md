# Deployment Notifications Without Vercel Webhooks (GitHub Actions → n8n → Supabase)

A reusable automation that delivers deployment notifications and persistent logging without relying on Vercel webhooks (free plan friendly). It uses:

- GitHub Actions to deploy (or notify-only)
- n8n to parse and fan out notifications (Slack/Discord)
- Supabase Postgres to log each deployment

This repository is designed as a portfolio-ready case study and a reusable template you can adapt to any project.

## Problem
Vercel webhooks are not available on the free plan, making real-time deployment notifications and logging harder to implement without upgrading. Teams still need visibility (Slack/Discord) and an audit trail (database).

## Solution (High-level)
- Use GitHub Actions as the transport: on push to `main`, the workflow deploys (optional) and POSTs a normalized JSON payload to an n8n Webhook.
- n8n parses the payload and routes it:
  - Success → Slack/Discord success channels
  - Failure → Slack/Discord alert channels
  - Always → Insert a row into Supabase `public.deployments_log`
- Works for both GitHub Actions JSON and Vercel webhook payloads (future-proof if you upgrade later).

## Architecture
See docs/architecture.md for a diagram and details. TL;DR:

- GitHub Actions → (optional) Vercel Deploy → Build JSON payload → POST to n8n Webhook
- n8n Code node parses to a normalized schema → IF routes → Slack/Discord + Supabase insert

## What’s included here
- Example GitHub workflow (deploy + notify) in README and docs
- n8n workflow export (sanitized) placeholder
- Supabase schema example for `deployments_log`
- Documentation scaffold for screenshots and demo

## How to use this in a real app
1) Copy the workflow file to your app repo at `.github/workflows/deploy.yml`.
2) Set repo secrets (in the app repo):
   - `VERCEL_TOKEN` (Vercel → Settings → Tokens)
   - `VERCEL_ORG_ID` (Vercel Team → Settings → General → Team ID)
   - `VERCEL_PROJECT_ID` (Vercel Project → Settings → General → Project ID)
   - `N8N_WEBHOOK_URL` = `https://<your-n8n-host>/webhook/vercel/deploy`
3) Import the n8n workflow (from this repo’s `n8n/` folder when provided) into your n8n instance.
4) In n8n, attach credentials:
   - Postgres credential (Supabase). Use SSL. Prefer a least-privilege user with INSERT + RLS policy.
   - Slack/Discord Incoming Webhooks (or disable those nodes).
5) Push a commit to `main` and verify:
   - GitHub Actions run
   - n8n Executions show parsed data
   - Slack/Discord messages
   - Supabase row inserted

## Notify-only mode (no deploy)
- If Vercel already auto-deploys on push, switch the workflow to notify-only:
  - Comment out the "Deploy to Vercel" step.
  - Still POST a payload to n8n (status, branch, commit SHA, etc.).

## Monorepo support
- Set `working-directory` in the Vercel action step to your app subfolder (e.g., `apps/web`).

## Security
- No secrets committed.
- GitHub secrets and n8n credentials manage tokens and passwords.
- Supabase: use a dedicated DB user (e.g., `n8n_deployer`) with INSERT only and an RLS insert policy.

## Troubleshooting (quick)
- Webhook 404 in browser: you used GET. Use POST with JSON.
- Parse node “Could not get parameter”: no input. Ensure Webhook received JSON; set Code node mode to “Run once for all items” and add a guard.
- Code node “Invalid token”: paste as plain text; remove hidden characters and smart quotes.
- Supabase NOT NULL on `timestamp`: ensure a fallback timestamp or DB default `now()`.

## Future work
- Add HMAC verification if/when using Vercel webhooks (Pro plan)
- Add scheduled digests (cron) in GitHub Actions or n8n
- Add dashboards for deployment trends (Supabase/Metabase)

## License
MIT (or your choice).
