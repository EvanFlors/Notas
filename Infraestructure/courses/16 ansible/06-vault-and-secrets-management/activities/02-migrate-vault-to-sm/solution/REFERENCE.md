# Solución de referencia — ans-06-02-migrate-vault-to-sm

Ejemplo completo de ADR que pasa el validador y satisface los criterios semánticos.

```markdown
# ADR 002 — Migración de secretos: de ansible-vault a AWS Secrets Manager

## Estado
Propuesto — pendiente aprobación de plataforma y seguridad.

## Contexto

Operamos 14 playbooks Ansible contra 60 hosts EC2 en 3 cuentas AWS
(dev, stg, prod) con un equipo de 8 personas. Todos los secretos viven en
`group_vars/*.yml` encriptados con **una sola** `ansible-vault` password
compartida por Slack:

- Un ex-miembro mantiene la password en su laptop (offboarding incompleto).
- La password no se rota desde hace 14 meses.
- No podemos auditar quién leyó `rds_master_password`.
- Dev y prod comparten password, violando el principio de minimo privilegio.

`ansible-vault` resuelve "no commitear secretos en claro". No resuelve
rotación, auditoría ni separación de scopes. Es un bastión mínimo; se
convirtió en el techo.

## Decisión

Migrar los secretos operacionales al patrón **lookup directo a AWS Secrets
Manager** desde Ansible. Mantener `ansible-vault` **solo** para dev local
transitorio durante la fase 1 y eliminarlo en fase 3.

### 1. Herramientas comparadas

| Eje | ansible-vault | SOPS | AWS Secrets Manager (lookup) | External Secrets Operator |
|-----|---------------|------|------------------------------|---------------------------|
| Tipo de cifrado | simetrico (password compartida) | asimetrico (KMS/age/PGP) | gestionado (KMS backend) | gestionado |
| Legibilidad del diff | ilegible (archivo entero) | legible (solo valores) | n/a (no vive en repo) | n/a |
| Rotacion | manual via `rekey` | re-encrypt con nueva key | automatica (Lambda rotator) | automatica |
| Auditoria | no | parcial (CloudTrail KMS) | si (CloudTrail GetSecretValue) | si (misma via backend) |
| Dependencia operativa | ninguna | KMS o PGP | AWS SM disponible | SM + cluster K8s + ESO |
| Scope por entorno | 1 password por vault ID | 1 recipient por archivo | IAM por path | IAM por path |

### 2. Mapa de secretos y destino

| Secreto hoy en vault | Destino | Justificación |
|----------------------|---------|---------------|
| `rds_master_password` | AWS Secrets Manager `prod/rds/password` | Candidato ideal: rotable por Lambda nativo. |
| `api_token_stripe`   | AWS Secrets Manager `prod/stripe/api`   | Rota manualmente desde consola Stripe → actualizar SM. |
| `ssh_deploy_key`     | SOPS con KMS (`age` fallback)           | Clave privada larga, varios recipients, consume mejor como archivo que como string SM. |

### 3. Snippet Ansible (lookup con `no_log`)

```yaml
- hosts: db
  gather_facts: false
  tasks:
    - name: Obtener password de RDS desde Secrets Manager
      ansible.builtin.set_fact:
        rds_password: "{{ lookup('amazon.aws.aws_secret', 'prod/rds/password', region='eu-west-1') }}"
      no_log: true

    - name: Aplicar password al usuario administrador
      community.postgresql.postgresql_user:
        name: admin
        password: "{{ rds_password }}"
        state: present
      no_log: true
```

En el lab usamos `fake-password-not-real`; en prod, el valor real **nunca**
aparece en el repo. `no_log: true` impide que `-vv` o un `register:` filtre
la variable al stdout del runner.

### 4. Plan de rotación

- **AWS SM**: Lambda rotator cada 90 días para RDS; manual sincronizado con el proveedor para Stripe.
- **SOPS**: `sops updatekeys ssh_deploy_key.enc` cuando entra/sale un recipient.
- **ansible-vault** (residual dev): deprecated; se elimina en fase 3.

### 5. Fases de corte

1. Habilitar SM en prod + política IAM de lectura por path. Migrar `rds_master_password`.
2. Migrar `api_token_stripe`. Introducir SOPS para `ssh_deploy_key`.
3. Eliminar `ansible-vault` del repo; dev usa SM con una política de solo lectura dev.

## Consecuencias

### Positivas
- Auditoría completa via CloudTrail por acceso a cada secreto.
- Rotación automática elimina el "no hemos rotado en 14 meses".
- Separación por IAM: dev no puede leer prod aunque tenga el repo.
- Un offboarding ya no implica rotar nada en el repo; basta revocar el acceso IAM.

### Negativas
- Nuevo single point of failure: si AWS SM eu-west-1 cae, el deploy falla.
- Coste: ~$0.40/secret/mes + $0.05/10k llamadas → despreciable a este volumen.
- Dependencia operativa de red: ya no se puede correr el playbook offline.
- Curva de aprendizaje: el equipo debe entender IAM para SM paths.

## Alternativas descartadas

1. **Quedarse en ansible-vault con rekey trimestral y una password por entorno**.
   Resuelve 2 de los 4 problemas (rotación + scope) pero no cubre auditoría ni
   evita el leak via laptops personales. Coste operativo residual alto.

2. **HashiCorp Vault self-hosted**.
   Mejor que SM para multi-cloud y para secretos dinámicos (short-lived),
   pero coste operativo alto para 8 personas y un solo cloud. Reevaluable
   si entramos en GCP o Azure.

3. **External Secrets Operator ahora**.
   Resuelve el problema en K8s, pero hoy los playbooks corren contra EC2
   bare metal. Lo adoptaremos para la app futura en EKS, no para esta base.
```

## Checklist de autoevaluación

- [ ] 6 secciones ADR presentes.
- [ ] Herramientas comparadas: ansible-vault, SOPS, External Secrets, AWS Secrets Manager.
- [ ] Snippet con `amazon.aws.aws_secret` y `no_log: true` en code fence.
- [ ] Mapa con los 3 secretos (`rds_master_password`, `api_token_stripe`, `ssh_deploy_key`).
- [ ] Tabla comparativa con al menos 3 ejes.
- [ ] Al menos 2 alternativas descartadas con razón.
- [ ] Mención de `fake-password-not-real` en los snippets.
- [ ] Validador en verde.
