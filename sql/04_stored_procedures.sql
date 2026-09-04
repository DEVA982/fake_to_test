CREATE OR REPLACE PROCEDURE fund_gig(
 p_client_id UUID,
 p_freelancer_id UUID,
 p_budget DECIMAL(12,2)
)
LANGUAGE plpgsql AS $$
DECLARE v_balance DECIMAL(12,2);
BEGIN
 IF p_budget <= 0 THEN RAISE EXCEPTION 'Budget must be greater than zero'; END IF;
 SELECT escrow_balance INTO v_balance FROM clients WHERE id=p_client_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Client does not exist'; END IF;
 IF v_balance < p_budget THEN RAISE EXCEPTION 'Insufficient escrow balance'; END IF;
 IF NOT EXISTS (SELECT 1 FROM freelancers WHERE id=p_freelancer_id) THEN
   RAISE EXCEPTION 'Freelancer does not exist';
 END IF;
 UPDATE clients SET escrow_balance=escrow_balance-p_budget WHERE id=p_client_id;
 INSERT INTO contracts(client_id,freelancer_id,budget,status)
 VALUES(p_client_id,p_freelancer_id,p_budget,'FUNDED');

EXCEPTION WHEN OTHERS THEN
 ROLLBACK;
 RAISE;
END; $$;
-- CALL fund_gig('client-uuid','freelancer-uuid',500.00);
