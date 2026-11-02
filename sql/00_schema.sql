-- A tiny "public library" domain, 100% synthetic.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE members (
    id         bigserial PRIMARY KEY,
    name       text        NOT NULL,
    email      text        NOT NULL,
    city       text        NOT NULL,
    created_at timestamptz NOT NULL
);

CREATE TABLE books (
    id             bigserial PRIMARY KEY,
    title          text    NOT NULL,
    author         text    NOT NULL,
    genre          text    NOT NULL,
    published_year integer NOT NULL
);

-- Note: no index on the foreign keys on purpose.
-- PostgreSQL does NOT create indexes for foreign keys automatically.
CREATE TABLE loans (
    id          bigserial PRIMARY KEY,
    member_id   bigint      NOT NULL REFERENCES members (id),
    book_id     bigint      NOT NULL REFERENCES books (id),
    loaned_at   timestamptz NOT NULL,
    due_at      timestamptz NOT NULL,
    returned_at timestamptz            -- NULL = still on loan
);
