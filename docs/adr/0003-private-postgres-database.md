# ADR-0003: Database is private PostgreSQL, reachable only from EKS nodes

Status: Accepted (2026-10-10)

## Context
RDS holds users' transactions and account balances, the most sensitive data in FinTrack.

## Decision
RDS PostgreSQL 16 on db.t3.micro, publicly_accessible = false, in private subnets.
Its security group allows 5432 only from the EKS node security group.
Dev-only trade-offs: no automated backups and skip_final_snapshot = true.

## Consequences
No direct access from outside the VPC. Data loss on destroy is accepted in dev.

## Reviewer should flag
publicly_accessible = true; any 0.0.0.0/0 or broad CIDR ingress on the database
security group; storage_encrypted turned off; backup or snapshot settings weakened
in a change that targets anything beyond dev.