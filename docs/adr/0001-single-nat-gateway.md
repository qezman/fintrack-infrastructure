# ADR-0001: Single NAT gateway

Status: Accepted (2026-10-10)

## Context

Private subnets (EKS nodes, RDS) need outbound internet for image pulls and updates.
A NAT gateway costs about $32/month plus data, and one per AZ doubles that.

## Decision

One NAT gateway in the first public subnet, shared by a single private route table
for both private subnets. Dev environment, cost over AZ-level resilience.

## Consequences

If that AZ fails, private subnets lose outbound access. Accepted for dev.

## Reviewer should flag

A second NAT gateway or EIP, or per-AZ private route tables. Say it contradicts this ADR and show the monthly cost impact.
