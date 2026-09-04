CREATE UNIQUE INDEX IF NOT EXISTS idx_active_gig
ON contracts(freelancer_id)
WHERE status = 'IN PROGRESS';

CREATE INDEX IF NOT EXISTS idx_contracts_completed_freelancer
ON contracts(freelancer_id, completed_at)
WHERE status = 'COMPLETED';

CREATE INDEX IF NOT EXISTS idx_freelancers_available
ON freelancers(is_available)
WHERE is_available = TRUE;
