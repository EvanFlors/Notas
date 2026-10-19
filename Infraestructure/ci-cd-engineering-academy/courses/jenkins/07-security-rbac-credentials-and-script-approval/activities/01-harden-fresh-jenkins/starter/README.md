# Starter — jk-07-01-harden-fresh-jenkins

Entregable: `jenkins.yaml` + `HARDENING-NOTES.md` en `/tmp/jk-07-harden/`.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/jk-07-harden
   cd /tmp/jk-07-harden
   ```
3. Crea `jenkins.yaml` con los **5 bloques** (A–E) descritos en `../README.md § 5.2`.
4. Verifica que es YAML válido:
   ```bash
   python3 -c "import yaml,sys; yaml.safe_load(open('jenkins.yaml')); print('OK YAML')"
   ```
5. Crea `HARDENING-NOTES.md` con las 5 secciones indicadas (`## Autenticacion`, etc.).
6. Valida:
   ```bash
   bash <ruta-repo>/courses/jenkins/07-security-rbac-credentials-and-script-approval/\
   activities/01-harden-fresh-jenkins/tests/validate.sh /tmp/jk-07-harden
   ```
7. Compara con `../solution/REFERENCE.md` para autoevaluarte.

## Esqueleto mínimo (empieza desde aquí)

```yaml
jenkins:
  systemMessage: "Managed by JCasC. Do not configure by UI."
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: "admin-bootstrap"
          password: "${ADMIN_BOOTSTRAP_PASSWORD}"
  authorizationStrategy:
    roleBased:
      roles:
        global:
          # TODO: admin role + readonly-everyone role
        items:
          # TODO: team-a-maintainers + team-b-maintainers
  crumbIssuer:
    standard:
      excludeClientIPFromCrumb: false

credentials:
  system:
    domainCredentials:
      - credentials:
          # TODO: 3 credentials dummy (string, usernamePassword, basicSSHUserPrivateKey)

security:
  scriptApproval:
    approvedSignatures:
      # TODO: 2+ firmas, SIN GroovyShell.evaluate ni MethodCall.invoke
```

## Red flags que el validador rechaza

- Secret literal en el YAML (`ghp_...`, `AKIA...`, string base64 largo plano).
- `scriptApproval` con `evaluate` o `invoke` no cualificado.
- Rol asignado al grupo `anonymous`.
- `allowsSignup: true`.
