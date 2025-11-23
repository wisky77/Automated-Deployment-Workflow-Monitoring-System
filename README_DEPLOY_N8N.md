# Deploy + Notify: GitHub Actions → Vercel → n8n → Slack/Discord → Supabase

This repo uses GitHub Actions to deploy to Vercel and notify an n8n workflow, which fans out to Slack/Discord and logs each deployment to Supabase Postgres.

## What this does
- On push to `main`, GitHub Actions:
  - Deploys to Vercel (optional; can be set to notify-only)
  - Posts a JSON payload to your n8n Webhook
- n8n parses and normalizes the payload, then:
  - Sends messages to Slack/Discord
  - Inserts a row in `public.deployments_log` in Supabase

## Prerequisites
- Vercel project already set up
- n8n instance reachable from GitHub runners
- Supabase project with a `public.deployments_log` table
  - Example columns: `timestamp timestamptz not null`, `commit_hash text`, `status text`, `url text`, `project text`, `branch text`, `deployment_id text`, `raw_payload jsonb`

## 1) Add the workflow file
Place this file at `.github/workflows/deploy.yml` in this repo (create folders if needed).

```
name: Deploy to Vercel and notify n8n

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Use Node
        uses: actions/setup-node@v4
        with:
          node-version: 18

      - name: Deploy to Vercel (Production)
        id: vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          working-directory: .
          scope: ${{ secrets.VERCEL_ORG_ID }}
          prod: true

      - name: Prepare payload for n8n
        id: payload
        run: |
          STATUS="success"
          if [ "${{ job.status }}" != "success" ]; then STATUS="failure"; fi
          URL="${{ steps.vercel.outputs.preview-url }}"
          DEPLOY_ID="${{ steps.vercel.outputs.preview-id }}"
          COMMIT_SHA="${{ github.sha }}"
          BRANCH="${{ github.ref_name }}"
          PROJECT="${{ github.repository }}"
          echo "json={\"status\":\"$STATUS\",\"url\":\"$URL\",\"deploymentId\":\"$DEPLOY_ID\",\"commitSha\":\"$COMMIT_SHA\",\"branch\":\"$BRANCH\",\"project\":\"$PROJECT\",\"createdAt\":$(date +%s000)}" >> $GITHUB_OUTPUT

      - name: Notify n8n
        if: always()
        run: |
          curl -s -X POST "$N8N_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d '${{ steps.payload.outputs.json }}'
        env:
          N8N_WEBHOOK_URL: ${{ secrets.N8N_WEBHOOK_URL }}
```

Monorepo: set `working-directory` to the app subfolder (e.g., `apps/web`).

Notify-only (skip Vercel deploy): comment out the "Deploy to Vercel" step and set `URL`/`DEPLOY_ID` to empty strings in the payload step.

## 2) Configure repository secrets (GitHub → Settings → Secrets and variables → Actions)
Add these in this repo:
- `VERCEL_TOKEN` → Vercel Settings → Tokens → Create Token
- `VERCEL_ORG_ID` → Vercel Team → Settings → General → Team ID
- `VERCEL_PROJECT_ID` → Vercel Project → Settings → General → Project ID
- `N8N_WEBHOOK_URL` → `https://<your-n8n-host>/webhook/vercel/deploy`

## 3) n8n workflow
- Import the prepared workflow into n8n (has a Code node named "Parse Vercel Payload").
- Webhook path: `vercel/deploy` (must match `N8N_WEBHOOK_URL`).
- Code node normalizes GitHub Action JSON and (optionally) Vercel webhook payloads.
- Connects to Slack/Discord HTTP nodes and a Postgres node that inserts into Supabase.

Recommended Code node options:
- Mode: Run once for all items (a.k.a. Execute once)
- Options: Always Output Data = ON (useful for debugging)

## 4) Supabase credential in n8n
- In n8n, create a Postgres credential:
  - Host: `db.<your-project-ref>.supabase.co`
  - Port: `5432`
  - Database: `postgres` (or your DB)
  - User/Password: either `postgres` + `service_role` (trusted env) or a dedicated `n8n_deployer` user with INSERT on `public.deployments_log`
  - SSL: Required
- Select this credential in the "Supabase: Log Deployment" node.
- Ensure the node's values expression always sets a timestamp, for example:

```
={{ [
  {
    timestamp: new Date(($json.normalized && $json.normalized.createdAt) ? $json.normalized.createdAt : Date.now()).toISOString(),
    commit_hash: ($json.normalized && $json.normalized.commitSha) || '',
    status: ($json.normalized && $json.normalized.status) || 'unknown',
    url: ($json.normalized && $json.normalized.url) || '',
    project: ($json.normalized && $json.normalized.project) || '',
    branch: ($json.normalized && $json.normalized.branch) || '',
    deployment_id: ($json.normalized && $json.normalized.deploymentId) || '',
    raw_payload: $json.raw || {}
  }
] }}
```

If `raw_payload` is TEXT, use `JSON.stringify($json.raw || {})` instead.

## 5) Test
- Push a small commit to `main`.
- GitHub → Actions: confirm the job runs.
- n8n → Executions: confirm run appears and the Code node outputs `normalized` fields.
- Slack/Discord: messages arrive (if URLs are set).
- Supabase: verify row exists:

```
select *
from public.deployments_log
order by timestamp desc
limit 5;
```

Manual test (no GitHub needed):
- In n8n Webhook node → "Listen for Test Event" → copy Test URL.
- POST JSON:

```
curl -X POST "<TEST_URL>" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "success",
    "url": "https://example.vercel.app",
    "deploymentId": "dpl_123",
    "commitSha": "abc123",
    "branch": "main",
    "project": "owner/repo",
    "createdAt": 1730000000000
  }'
```

## 6) Troubleshooting
- Webhook shows 404 in browser: use POST with JSON (browser does GET).
- Parse node "Could not get parameter": no input. Ensure Webhook POST succeeded; set Mode=Run once and add a guard.
- Code node "Invalid token": paste as plain text; remove hidden characters/smart quotes.
- Supabase NOT NULL error on `timestamp`: ensure fallback timestamp in expression or set a DB default `now()`.
- Double deploys: disable Vercel auto Git deploy if GitHub Actions also deploys, or switch workflow to notify-only.

## 7) Optional
- Cron (GitHub): add `on.schedule` to run periodically for heartbeat/digest.
- Cron (n8n): add a Cron node to poll Vercel/GitHub and reuse the same Slack/Supabase logic.
- Security: use a least-privilege DB user + RLS policy; rotate secrets regularly.

## Summary
- Workflow file lives at `.github/workflows/deploy.yml`.
- Secrets: `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`, `N8N_WEBHOOK_URL`.
- n8n parses, notifies Slack/Discord, and logs to Supabase.
- Works even without Vercel webhooks (free plan) by using GitHub Actions as the transport.
