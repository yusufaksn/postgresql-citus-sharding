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

SELECT create_distributed_table('tickets', 'tenant_id');