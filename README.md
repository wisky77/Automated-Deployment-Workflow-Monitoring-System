# GitHub → Vercel → n8n → Slack/Discord → Supabase (Deploy Notifications)

This repository contains a ready-to-import n8n workflow, a Supabase schema, and documentation to implement a full-stack automation flow:

- Trigger: Push to `main` on GitHub
- Deployment: Vercel builds and deploys the app
- Webhook: Vercel sends a deployment event to n8n
- Notifications: n8n posts to Slack (and optionally Discord)
- Logging: n8n writes deployment metadata to Supabase for analytics

## Architecture

```mermaid
flowchart LR
  A[GitHub Push to main] -->|Vercel Git Integration| B[Vercel Deployment]
  B -->|Vercel Webhook (deployment.ready/error)| C[n8n Webhook]
  C -->|Parse + Transform| D[Slack #deployments]
  C -->|Optional| E[Discord #dev-updates]
  C -->|Insert| F[(Supabase Postgres)]

```

## Deliverables in this repo
- `n8n_workflow.json`: Importable n8n workflow implementing the logic
- `supabase_schema.sql`: Postgres schema (for Supabase) to store deployment logs
- `README.md`: Setup instructions and architecture
- `examples/messages.md`: Example Slack/Discord messages

---

## Setup: Step-by-step

### 1) GitHub → Vercel (trigger on push to main)
- Connect your GitHub repo to Vercel (Vercel dashboard → Add New → Project → Import Git Repository)
- Ensure your production branch is `main` (Project → Settings → Git → Production Branch)
- On push to `main`, Vercel will automatically build and deploy

### 2) Vercel → n8n (webhook on deployment)
- In Vercel: Project → Settings → Webhooks → Add Webhook
  - URL: Your n8n Webhook URL for the Webhook node in this flow (e.g., `https://<your-n8n-host>/webhook/vercel/deploy`)
  - Recommended events: `deployment.ready` and `deployment.error`
- Optionally configure a HMAC signature secret in Vercel and validate it in n8n (see Hardening section below)

### 3) n8n workflow import and configuration
- In n8n, Import `n8n_workflow.json`
- Update the following nodes/fields:
  - Webhook node path: if you prefer a different path than `vercel/deploy`
  - Slack HTTP Request nodes (`Slack: Success`, `Slack: Failure`): replace webhook URL with your Slack Incoming Webhook URL
  - Discord HTTP Request nodes: replace webhook URL with your Discord channel webhook (or disable these nodes)
  - Postgres node credentials: create credentials pointing to your Supabase Postgres (host, db, user, password, SSL). Then set the credential reference on the `Supabase: Log Deployment` node
- Execute test with a sample payload (from Vercel docs or by triggering a preview deployment)

### 4) Slack setup
- Create an Incoming Webhook (Slack → Apps → Incoming Webhooks → Add to Workspace)
- Choose the `#deployments` channel
- Copy the Webhook URL and paste into the Slack nodes in n8n

### 5) Optional: Discord mirroring
- In your Discord server, create a Webhook on `#dev-updates`
- Paste the Webhook URL into the two Discord nodes
- Or disable these nodes if not needed

### 6) Supabase for analytics
- In Supabase SQL editor, run `supabase_schema.sql`
- In n8n, create Postgres credentials with your Supabase connection
- The workflow inserts deployment records into `public.deployments_log`

---

## Security hardening (recommended)
- Validate Vercel webhook signature:
  - Configure a secret on the Vercel webhook
  - Add a Function node before parsing to verify signature using the request headers (`x-vercel-signature`) and shared secret
- Restrict the Webhook node to only accept events from Vercel IPs or reverse proxy with filtering
- Enable RLS on Supabase tables and use Service Role key server-side only

---

## Environment mappings and fields
The parsing Function node attempts to normalize common Vercel fields:
- Status mapping: `READY → success`, `ERROR/CANCELED → failure`, `BUILDING/INITIALIZING → building`
- URL is normalized to a fully qualified URL if Vercel sends a bare hostname
- Also attempts to pull: `project`, `branch`, `commitSha`, `commitMessage`, `deploymentId`, `createdAt`, and `error`

---

## Example messages
See `examples/messages.md` for samples your Slack/Discord will receive.

---

## Troubleshooting
- If Slack messages are not posting: verify Incoming Webhook URL and that your workspace allows webhooks
- If Discord messages fail: ensure the webhook URL is correct and has permissions to post in the channel
- If Supabase insert fails: confirm credential config and that `deploy_status` type and `deployments_log` table exist
- Vercel payloads vary by event type; use the `raw_payload` column for debugging and adjust parsing as needed

---

## Optional: GitHub Action ping to n8n (alternative)
While Vercel webhooks are preferred, you could also notify n8n after a successful Vercel CLI deploy via a GitHub Action. This repo focuses on Vercel native webhooks.

---

## License
MIT
