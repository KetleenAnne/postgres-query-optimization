-- Members who never borrowed a book (correlated count, evaluated once per member)
SELECT count(*)
FROM members m
WHERE (SELECT count(*) FROM loans l WHERE l.member_id = m.id) = 0;
