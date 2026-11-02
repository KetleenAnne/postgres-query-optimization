CREATE INDEX books_title_trgm_idx ON books USING gin (title gin_trgm_ops);
