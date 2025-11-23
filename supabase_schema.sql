-- Supabase (Postgres) schema for deployment analytics
-- Create an enum for deployment status for consistency
DO $$ BEGIN
  CREATE TYPE deploy_status AS ENUM ('building', 'success', 'failure');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS public.deployments_log (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  timestamp     timestamptz NOT NULL DEFAULT now(),
  commit_hash   text,
  status        deploy_status NOT NULL,
  url           text,
  project       text,
  branch        text,
  deployment_id text,
  raw_payload   jsonb,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- Helpful indexes for analytics
CREATE INDEX IF NOT EXISTS deployments_log_project_time_idx ON public.deployments_log (project, timestamp DESC);
CREATE INDEX IF NOT EXISTS deployments_log_status_time_idx ON public.deployments_log (status, timestamp DESC);
CREATE INDEX IF NOT EXISTS deployments_log_branch_time_idx ON public.deployments_log (branch, timestamp DESC);

-- Row Level Security (optional but recommended)
ALTER TABLE public.deployments_log ENABLE ROW LEVEL SECURITY;

-- Simple RLS policy (adjust as needed). For server-side usage via service key.
DO $$ BEGIN
  CREATE POLICY deployments_log_all ON public.deployments_log
    FOR ALL
    USING (true)
    WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
