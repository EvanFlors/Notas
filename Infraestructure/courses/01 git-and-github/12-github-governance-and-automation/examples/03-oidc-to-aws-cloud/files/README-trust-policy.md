# trust-policy.json — campo a campo

```
Version       — IAM policy language (always 2012-10-17).
Statement[]   — list of permission grants.
  Effect      — Allow / Deny.
  Principal   — who can assume. For OIDC: the Federated provider ARN
                of GitHub's OIDC in your account. The DUMMY account
                123456789012 above must be replaced by your real AWS
                account ID.
  Action      — sts:AssumeRoleWithWebIdentity for OIDC.
  Condition
    StringEquals
      aud     — must be "sts.amazonaws.com". GitHub puts "sts.amazonaws.com"
                in the JWT when the aws-actions/configure-aws-credentials
                action is used.
    StringLike
      sub     — restricts WHICH workflows can assume. Patterns:
                  repo:ORG/REPO:ref:refs/heads/main
                  repo:ORG/REPO:environment:production
                  repo:ORG/REPO:pull_request
                NEVER use repo:ORG/* unless you explicitly want any
                repo of the org to assume (treat as a shared credential).
```

## Checklist antes de aplicar

- [ ] Account ID real (no 123456789012).
- [ ] Owner/repo reales en `sub`.
- [ ] Role name con convención clara (`gha-<repo>-<env>`).
- [ ] Role attached policy mínimo necesario (no `AdministratorAccess`).
- [ ] Session duration ≤ 1 h.
- [ ] CloudTrail activo (role usage debe ser auditable).
