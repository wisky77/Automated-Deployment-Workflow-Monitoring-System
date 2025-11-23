# Architecture: GitHub Actions → Vercel → n8n → Slack/Discord → Supabase

This automation uses GitHub Actions as the event transport to avoid Vercel webhook limitations on the free plan.

## Diagram
```mermaid
flowchart LR
  A[Git Push] -->|GitHub Actions| B(Deploy to Vercel)
  B --> C{Prepare JSON payload}
  C -->|POST| D[n8n Webhook /webhook/vercel/deploy]
  D --> E[Parse (Code)]
  E --> F{status == success?}
  F -->|Yes| G[Slack Success]
  F -->|No| H[Slack Failure]
  E --> I[Supabase: insert deployments_log]
  G-.->J[Discord (optional)]
  H-.->J[Discord (optional)]
```

## Data contract (normalized)
The n8n Code node outputs a consistent JSON structure for downstream nodes:

```
{
  "normalized": {
    "status": "success|failure|building",
    "vercelStatus": "READY|ERROR|...",
    "event": "github_action_deploy|deployment|...",
    "url": "https://...",
    "project": "owner/repo",
    "commitSha": "abc123",
    "commitMessage": "optional",
    "branch": "main",
    "deploymentId": "dpl_xxx",
    "createdAt": 1730000000000,
    "error": null
  },
  "raw": { /* original payload */ }
}
```

## Supabase schema example
```
create table if not exists public.deployments_log (
  timestamp      timestamptz not null default now(),
  commit_hash    text,
  status         text,
  url            text,
  project        text,
  branch         text,
  deployment_id  text,
  raw_payload    jsonb
);
```

Grant and RLS (example):
```
create user n8n_deployer with password 'YOUR_SECURE_PASSWORD_HERE';
grant usage on schema public to n8n_deployer;
grant insert on table public.deployments_log to n8n_deployer;
alter table public.deployments_log enable row level security;
create policy "allow insert from n8n_deployer"
  on public.deployments_log
  for insert
  to n8n_deployer
  with check (true);
```

## Variations
- Notify-only mode: remove the Vercel deploy step from the workflow.
- Monorepo: set the action `working-directory` to the app subfolder.
- Cron: add a scheduled trigger in GitHub or an n8n Cron node to produce daily summaries.
