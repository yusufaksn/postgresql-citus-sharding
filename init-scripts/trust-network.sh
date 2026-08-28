#!/bin/bash
set -e
# Prepend so this rule is matched BEFORE the default catch-all password rule
sed -i '1i host all all 172.28.0.0/16 trust' "$PGDATA/pg_hba.conf"