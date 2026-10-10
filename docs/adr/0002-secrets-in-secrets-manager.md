# ADR-0002: Secrets live in AWS Secrets Manager, synced by External Secrets

Status: Accepted (2026-10-10)

## Context

The backend needs DATABASE_URL and JWT_SECRET. Secrets must never be committed to git.

## Decision

Terraform writes secrets to AWS Secrets Manager from sensitive variables. The External Secrets Operator reads them through a scoped IAM role and creates Kubernetes secrets.

## Consequences

Secret values exist in Terraform state, so the state bucket must stay private, encrypted and tightly access-controlled.

## Reviewer should flag

Hardcoded passwords or tokens in .tf files, Helm values or manifests; secrets passed
as plain environment variables; IAM policies granting secretsmanager access to "\*".
