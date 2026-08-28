CREATE TABLE ticket_comments (
    id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    ticket_id UUID NOT NULL,
    comment TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_comments_tenant_ticket_created
    ON ticket_comments (tenant_id, ticket_id, created_at DESC);


SELECT create_distributed_table(
    'ticket_comments',
    'tenant_id'
);