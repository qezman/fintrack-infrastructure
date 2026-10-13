# ADR-0004: Fixed-size group of small nodes

Status: Accepted (2026-10-10)

## Context

Dev runs the app plus a platform stack (Argo CD, Argo Rollouts, Kyverno, Prometheus,
Loki, ingress, External Secrets). EDIT THIS if the real reason differs: t3.small nodes
have little RAM and a low pod limit, so the stack needs several of them.

## Decision

One managed node group of t3.small instances: desired 5, min 2, max 5.
Desired equals max, so in practice it is a fixed 5 nodes with no headroom to scale.
The environment is torn down when not in use to avoid paying for idle nodes.

## Consequences

Roughly $75/month for nodes if left running 24/7. No room for autoscaling.

## Reviewer should flag

A larger instance type, a higher max_size or desired_size, or a second node group.
Show the monthly cost impact against the budget in app-context.yaml.
