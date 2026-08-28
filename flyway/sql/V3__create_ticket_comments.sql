CREATE TABLE ticket_comments (
    id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    ticket_id UUID NOT NULL,
    comment TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

SELECT create_distributed_table(
    'ticket_comments',
    'tenant_id'
);