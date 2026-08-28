CREATE TABLE tickets (
    id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    description VARCHAR(600),
    notes VARCHAR(1000),
    assignee VARCHAR(50),
    ticket_date TIMESTAMP,
    priority_type VARCHAR(50),
    ticket_status VARCHAR(50)
);


-- 1) Speeds up dashboard-style queries that filter a tenant's tickets by status and sort by date.
CREATE INDEX idx_tickets_tenant_status_date
    ON tickets (tenant_id, ticket_status, ticket_date DESC);

-- 2) Speeds up "my assigned tickets" queries that filter by tenant, assignee, and status together.
CREATE INDEX idx_tickets_tenant_assignee_status
    ON tickets (tenant_id, assignee, ticket_status);


-- 3) Keeps the index small by covering only active tickets, which is what most operational queries filter on.
CREATE INDEX idx_tickets_tenant_open_date
    ON tickets (tenant_id, ticket_date DESC)
    WHERE ticket_status IN ('OPEN', 'IN_PROGRESS');

-- 4) Optimizes the urgent-queue query by indexing only high-priority tickets that are not yet closed.
CREATE INDEX idx_tickets_tenant_high_priority
    ON tickets (tenant_id, ticket_date DESC)
    WHERE priority_type = 'HIGH' AND ticket_status <> 'CLOSED';    


SELECT create_distributed_table('tickets', 'tenant_id');