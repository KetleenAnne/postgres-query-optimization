-- Same question, as an anti-join
SELECT count(*)
FROM members m
WHERE NOT EXISTS (SELECT 1 FROM loans l WHERE l.member_id = m.id);
