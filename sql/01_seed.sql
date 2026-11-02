-- Synthetic data (fixed seed, so the numbers are reproducible).
-- 100k members, 300k books, 2M loans.
SELECT setseed(0.42);

INSERT INTO members (name, email, city, created_at)
SELECT
    (ARRAY['Ana','Bruno','Carla','Diego','Elisa','Felipe','Gabi','Hugo','Iris','Joao'])[1 + floor(random() * 10)::int]
      || ' ' ||
    (ARRAY['Silva','Souza','Costa','Lima','Alves','Rocha','Dias','Melo','Cruz','Nunes'])[1 + floor(random() * 10)::int],
    'member' || g || '@example.com',
    (ARRAY['Juiz de Fora','Belo Horizonte','Rio de Janeiro','Sao Paulo','Curitiba','Recife'])[1 + floor(random() * 6)::int],
    now() - (random() * 1500) * interval '1 day'
FROM generate_series(1, 100000) AS g;

INSERT INTO books (title, author, genre, published_year)
SELECT
    (ARRAY['The','A','Our','Lost','Secret','Silent','Last','Golden','Hidden','Wild'])[1 + floor(random() * 10)::int]
      || ' ' ||
    CASE WHEN random() < 0.001 THEN 'Lighthouse'
         ELSE (ARRAY['Garden','Library','Cat','Coffee','Algorithm','River','Code','Night','Orchard','Compass','Lantern','Archive'])[1 + floor(random() * 12)::int]
    END
      || ' of ' ||
    (ARRAY['Dreams','Data','Winter','Memory','Stars','Queries','Silence','Tomorrow','Rain','Ink'])[1 + floor(random() * 10)::int]
      || ' #' || g,
    (ARRAY['A. Writer','B. Author','C. Novelist','D. Poet','E. Scholar'])[1 + floor(random() * 5)::int],
    (ARRAY['Fiction','Tech','Fantasy','History','Science','Poetry'])[1 + floor(random() * 6)::int],
    1950 + floor(random() * 75)::int
FROM generate_series(1, 300000) AS g;

-- member_id <= 90000 on purpose: the last 10k members never borrowed anything.
-- ~2% of loans are still open (returned_at IS NULL).
INSERT INTO loans (member_id, book_id, loaned_at, due_at, returned_at)
SELECT
    m, b, l, l + interval '14 days',
    CASE WHEN random() < 0.02 THEN NULL
         ELSE l + (random() * 13) * interval '1 day' END
FROM (
    SELECT 1 + floor(random() * 90000)::bigint  AS m,
           1 + floor(random() * 300000)::bigint AS b,
           now() - (random() * 1095) * interval '1 day' AS l
    FROM generate_series(1, 2000000)
) AS t;

ANALYZE;
