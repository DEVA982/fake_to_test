CREATE OR REPLACE FUNCTION log_escrow_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP = 'INSERT' THEN
   INSERT INTO wallet_audit_logs(client_id,amount_changed,action_type,balance_after)
   VALUES(NEW.id,NEW.escrow_balance,'INITIAL_BALANCE',NEW.escrow_balance);
 ELSIF OLD.escrow_balance IS DISTINCT FROM NEW.escrow_balance THEN
   INSERT INTO wallet_audit_logs(client_id,amount_changed,action_type,balance_after)
   VALUES(NEW.id,NEW.escrow_balance-OLD.escrow_balance,'ESCROW_BALANCE_UPDATE',NEW.escrow_balance);
 END IF;
 RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_escrow_audit ON clients;
CREATE TRIGGER trg_escrow_audit
AFTER INSERT OR UPDATE OF escrow_balance ON clients
FOR EACH ROW EXECUTE FUNCTION log_escrow_change();
