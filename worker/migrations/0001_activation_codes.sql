CREATE TABLE activation_codes (
  code_hash TEXT PRIMARY KEY,
  redeemed_at INTEGER,
  license_id TEXT,
  app_id TEXT,
  device_id TEXT
);
