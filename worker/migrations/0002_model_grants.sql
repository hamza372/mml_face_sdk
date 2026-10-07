CREATE TABLE model_grants (
  grant_hash TEXT PRIMARY KEY,
  model_key TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  redeemed_at INTEGER
);

CREATE INDEX model_grants_expiry ON model_grants(expires_at);
