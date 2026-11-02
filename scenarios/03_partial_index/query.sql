-- The 50 oldest overdue loans (still not returned, due more than 30 days ago)
SELECT id, member_id, due_at
FROM loans
WHERE returned_at IS NULL
  AND due_at < now() - interval '30 days'
ORDER BY due_at
LIMIT 50;
