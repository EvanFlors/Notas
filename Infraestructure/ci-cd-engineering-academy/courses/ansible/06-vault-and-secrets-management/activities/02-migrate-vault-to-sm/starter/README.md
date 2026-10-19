# Starter — ans-06-02-migrate-vault-to-sm

Esta actividad es **independiente**: no hay código ni plantilla que ejecutar. Tu entregable es un ADR Markdown escrito por ti.

## Pasos

1. Lee `../README.md` completo y recorre `examples/03-sops-vs-external-secrets/`.
2. Prepara el directorio: `mkdir -p /tmp/ans-06-sm && cd /tmp/ans-06-sm`.
3. Crea `ADR-SECRETS-MIGRATION.md` con las 6 secciones requeridas (ADR, Estado, Contexto, Decisión, Consecuencias, Alternativas).
4. Incluye el mapa de los 3 secretos (`rds_master_password`, `api_token_stripe`, `ssh_deploy_key`), el snippet con `amazon.aws.aws_secret` + `no_log: true`, la tabla comparativa y las alternativas descartadas.
5. Valida: `bash <repo>/courses/ansible/06-vault-and-secrets-management/activities/02-migrate-vault-to-sm/tests/validate.sh /tmp/ans-06-sm`.
6. Compara con `../solution/REFERENCE.md`.

## Plantilla sugerida

```markdown
# ADR 002 — Migración de secretos de ansible-vault a AWS Secrets Manager

## Estado
Propuesto

## Contexto
<equipo de 8 personas, 14 playbooks, 3 cuentas AWS, un unico vault pass compartido,
leaks potenciales por offboarding, sin auditoria, sin rotacion>

## Decisión

### 1. Herramientas comparadas

| Eje | ansible-vault | SOPS | AWS Secrets Manager (lookup) | External Secrets Operator |
|-----|---------------|------|------------------------------|---------------------------|
| Cifrado | simetrico | asimetrico (KMS/age) | gestionado | gestionado |
| Diffs | ilegibles | legibles | n/a | n/a |
| Rotacion | manual (rekey) | re-encrypt | automatica (Lambda) | automatica |
| Auditoria | no | parcial (CloudTrail KMS) | si (CloudTrail) | si |
| Dependencia externa | ninguna | KMS/age | AWS SM | SM + cluster K8s |

### 2. Mapa de secretos
- `rds_master_password` → AWS Secrets Manager (`prod/rds/password`).
- `api_token_stripe` → AWS Secrets Manager (`prod/stripe/api`).
- `ssh_deploy_key` → SOPS con KMS mientras siga siendo un archivo (clave larga).

### 3. Snippet Ansible (lookup)
```yaml
- name: Obtener password de RDS
  ansible.builtin.set_fact:
    rds_password: "{{ lookup('amazon.aws.aws_secret', 'prod/rds/password', region='eu-west-1') }}"
  no_log: true
```
(En lab, `fake-password-not-real`; en prod, el valor real nunca aparece aqui.)

### 4. Rotacion
- SM: Lambda rotator cada 90 dias para RDS.
- SOPS: `sops updatekeys ssh_deploy_key.enc` ante nuevos recipients.
- ansible-vault: deprecated — solo quedara temporalmente en dev.

## Consecuencias
### Positivas
- ...
### Negativas
- ...

## Alternativas descartadas
1. **Quedarse en ansible-vault con rekey trimestral**: no resuelve auditoria.
2. **HashiCorp Vault self-hosted**: potente pero coste operativo alto para 8 personas.
```
