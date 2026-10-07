ALTER TABLE activation_codes ADD COLUMN allowed_app_id TEXT;
ALTER TABLE activation_codes ADD COLUMN enabled INTEGER NOT NULL DEFAULT 1;

CREATE TABLE license_activations (
  license_id TEXT PRIMARY KEY,
  code_hash TEXT NOT NULL,
  app_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  platform TEXT NOT NULL,
  activated_at INTEGER NOT NULL
);

CREATE INDEX license_activations_code ON license_activations(code_hash);
