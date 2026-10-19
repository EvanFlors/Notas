# Starter — ans-09-02-tf-ansible-or-packer-ansible-adr

Esta actividad es **independiente**: no hay código ni plantilla que ejecutar. Tu entregable es un ADR Markdown escrito por ti.

## Pasos

1. Lee `../README.md` completo y recorre los tres `examples/` del módulo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/ans-09-02
   cd /tmp/ans-09-02
   ```
3. Crea `ADR-MUTABLE-VS-IMMUTABLE.md` con las 6 secciones requeridas:
   - Estado, Contexto, Decisión, Consecuencias, Alternativas (y encabezado ADR).
4. Incluye en la Decisión:
   - Patrón elegido para los **3 workloads** (`legacy-billing`, `checkout-api`, `analytics-platform`).
   - **Tabla de trade-offs** (Markdown con `|`) con al menos: drift, blast radius, rollback, build time / iteración.
   - Mención explícita de `Packer`, `Terraform`, `Ansible`, `AWX` o `AAP`, `mutable`, `immutable` (o `inmutable`).
   - Mención a **secretos** (Secrets Manager / Vault).
   - Mención a **EKS/Kubernetes** y por qué Ansible pierde relevancia ahí.
5. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/ansible/09-hybrid-with-terraform-packer-and-awx-aap/activities/02-tf-ansible-or-packer-ansible-adr/tests/validate.sh /tmp/ans-09-02
   ```
6. Compara tu ADR con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** el validador comprueba estructura, no semántica. La corrección conceptual la revisas tú contra la referencia.

## Plantilla sugerida (opcional)

```markdown
# ADR 001 — Mutable (TF+Ansible) vs immutable (Packer+Ansible)

## Estado
Propuesto

## Contexto
<los 3 workloads, el problema, los constraints>

## Decisión

### 1. Por workload

- `legacy-billing`: patrón MUTABLE (TF + Ansible converge). Razones: ...
- `checkout-api`: patrón IMMUTABLE (Packer + AMI + TF). Razones: ...
- `analytics-platform`: no-Ansible (EKS + Helm + GitOps). Razones: ...

### 2. Tabla de trade-offs

| Dimensión | Mutable | Immutable |
|-----------|---------|-----------|
| Drift | ... | ... |
| Blast radius | ... | ... |
| Rollback | ... | ... |
| Build time / velocidad | ... | ... |
| Secretos | ... | ... |

### 3. AWX/AAP
<dónde aporta, dónde no>

## Consecuencias
### Positivas
- ...
### Negativas
- ...

## Alternativas descartadas
### Alt A: todo immutable
- Por qué no: ...
### Alt B: todo mutable
- Por qué no: ...
```
