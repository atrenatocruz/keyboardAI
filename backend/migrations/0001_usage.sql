CREATE TABLE IF NOT EXISTS usage (
  install_id TEXT NOT NULL,
  day        TEXT NOT NULL,
  count      INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (install_id, day)
);
