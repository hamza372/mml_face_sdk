ALTER TABLE activation_codes ADD COLUMN license_type TEXT NOT NULL DEFAULT 'lifetime';
ALTER TABLE activation_codes ADD COLUMN trial_days INTEGER;
ALTER TABLE activation_codes ADD COLUMN trial_started_at INTEGER;
ALTER TABLE activation_codes ADD COLUMN allowed_platform TEXT;
ALTER TABLE activation_codes ADD COLUMN label TEXT;
ALTER TABLE activation_codes ADD COLUMN created_at INTEGER;

CREATE INDEX activation_codes_app ON activation_codes(allowed_app_id);
