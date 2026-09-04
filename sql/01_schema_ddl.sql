CREATE EXTENSION IF NOT EXISTS pgcrypto;
DROP TABLE IF EXISTS wallet_audit_logs CASCADE;
DROP TABLE IF EXISTS contracts CASCADE;
DROP TABLE IF EXISTS freelancers CASCADE;
DROP TABLE IF EXISTS clients CASCADE;

CREATE TABLE clients (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 name VARCHAR(100) NOT NULL,
 escrow_balance DECIMAL(12,2) NOT NULL DEFAULT 0.00 CHECK (escrow_balance >= 0.00)
);

CREATE TABLE freelancers (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 name VARCHAR(100) NOT NULL,
 latitude DECIMAL(9,6),
 longitude DECIMAL(9,6),
 is_available BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE contracts (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 client_id UUID NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
 freelancer_id UUID NOT NULL REFERENCES freelancers(id) ON DELETE RESTRICT,
 budget DECIMAL(12,2) NOT NULL CHECK (budget > 0),
 status VARCHAR(20) NOT NULL CHECK (status IN ('FUNDED','IN PROGRESS','COMPLETED')),
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 completed_at TIMESTAMPTZ
);

CREATE TABLE wallet_audit_logs (
 id BIGSERIAL PRIMARY KEY,
 client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
 amount_changed DECIMAL(12,2) NOT NULL,
 action_type VARCHAR(50) NOT NULL,
 balance_after DECIMAL(12,2) NOT NULL CHECK (balance_after >= 0),
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_contracts_client ON contracts(client_id);
CREATE INDEX idx_contracts_freelancer ON contracts(freelancer_id);
CREATE INDEX idx_contracts_created_at ON contracts(created_at);
CREATE INDEX idx_audit_client_created ON wallet_audit_logs(client_id, created_at);
