CREATE INDEX loans_open_due_idx ON loans (due_at) WHERE returned_at IS NULL;
