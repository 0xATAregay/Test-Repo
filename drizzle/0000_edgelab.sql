-- EdgeLab baseline cloud schema. Generated-equivalent SQL is kept explicit for environments where drizzle-kit is not available during bootstrap.
CREATE TABLE IF NOT EXISTS users (id text PRIMARY KEY, email text UNIQUE, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS profiles (id text PRIMARY KEY, user_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE, display_name text NOT NULL, time_zone text NOT NULL, study_days jsonb NOT NULL, session_length text NOT NULL, prior_knowledge text NOT NULL, goal text NOT NULL, resources jsonb NOT NULL, has_written_setup boolean NOT NULL, week_start text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());
CREATE UNIQUE INDEX IF NOT EXISTS profiles_user_uidx ON profiles(user_id);
CREATE TABLE IF NOT EXISTS playbooks (id text PRIMARY KEY, user_id text NOT NULL REFERENCES users(id), name text NOT NULL, status text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS playbook_versions (id text PRIMARY KEY, playbook_id text NOT NULL REFERENCES playbooks(id), version integer NOT NULL, reason text NOT NULL, snapshot jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now());
CREATE UNIQUE INDEX IF NOT EXISTS playbook_version_uidx ON playbook_versions(playbook_id,version);
CREATE TABLE IF NOT EXISTS lab_cases (id text PRIMARY KEY, context text NOT NULL, difficulty integer NOT NULL, bars jsonb NOT NULL, reveal_at integer NOT NULL, expected text NOT NULL);
CREATE TABLE IF NOT EXISTS lab_decisions (id text PRIMARY KEY, user_id text NOT NULL REFERENCES users(id), case_id text NOT NULL REFERENCES lab_cases(id), playbook_version_id text NOT NULL REFERENCES playbook_versions(id), classification text NOT NULL, context text NOT NULL, confidence integer NOT NULL, reasoning text NOT NULL, score integer NOT NULL, payload jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now());
CREATE UNIQUE INDEX IF NOT EXISTS lab_decision_user_case_uidx ON lab_decisions(user_id,case_id);
CREATE TABLE IF NOT EXISTS journal_entries (id text PRIMARY KEY, user_id text NOT NULL REFERENCES users(id), type text NOT NULL, title text NOT NULL, payload jsonb NOT NULL, deleted_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS journal_user_created_idx ON journal_entries(user_id,created_at);
CREATE TABLE IF NOT EXISTS xp_events (id text PRIMARY KEY, user_id text NOT NULL REFERENCES users(id), event_key text NOT NULL, amount integer NOT NULL, reason text NOT NULL, created_at timestamptz NOT NULL DEFAULT now());
CREATE UNIQUE INDEX IF NOT EXISTS xp_event_user_key_uidx ON xp_events(user_id,event_key);
-- Remaining tables are defined authoritatively in db/schema.ts and generated with `npm run db:generate`.
