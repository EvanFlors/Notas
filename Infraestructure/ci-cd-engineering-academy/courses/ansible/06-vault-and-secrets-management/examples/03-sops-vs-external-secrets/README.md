# Ejemplo 03 — `ansible-vault` vs SOPS vs External Secrets Operator

> **Lectura y análisis, no ejecución.** Objetivo: tener claro cuál elegir en cada escenario y por qué `ansible-vault` deja de bastar.

## 1. Las tres piezas

### `ansible-vault`
- **Qué es**: encripta archivos YAML (o campos) con AES-256-CTR usando una **password simétrica**.
- **Dónde vive el cifrado**: en el repo.
- **Cómo se abre**: Ansible lo desencripta en tiempo de ejecución con la password.
- **Nativo de Ansible**: cero dependencias externas.

### SOPS (Mozilla, hoy en `getsops/sops`)
- **Qué es**: encripta solo los **valores** de un YAML/JSON/ENV/INI dejando las keys en claro, usando claves **asimétricas** de KMS (AWS/GCP/Azure), **age** o PGP.
- **Dónde vive el cifrado**: en el repo.
- **Cómo se abre**: cualquier herramienta con el binario `sops` y acceso a la key (p. ej. permisos IAM sobre la KMS key).
- **No es específico de Ansible**: Terraform, Helm, kustomize, `kubectl` plugins — todos lo consumen.

### External Secrets Operator (ESO)
- **Qué es**: un **operator de Kubernetes** que sincroniza secretos desde un backend externo (AWS Secrets Manager, HashiCorp Vault, GCP SM, Azure KV, 1Password, Doppler...) hacia `Secret` nativos de K8s.
- **Dónde vive el cifrado**: **no en el repo**. Solo vive el CRD `ExternalSecret` que apunta al path del backend.
- **Cómo se abre**: ESO corre en el cluster con un `ServiceAccount` autorizado al backend y materializa el `Secret` cada N minutos.
- **Es K8s-only**: no aplica fuera del cluster.

## 2. Walkthrough comparativo: "quiero el password de la DB en prod"

### Opción A — `ansible-vault`

1. Encriptas `group_vars/prod.yml` con `ansible-vault encrypt --vault-id prod@...`.
2. Commiteas el archivo cifrado.
3. El runner de CI tiene la password en `AWS_VAULT_PROD_PASS` (variable de entorno) o la lee de un script.
4. `ansible-playbook --vault-id prod@script.sh site.yml` desencripta y aplica.

Problemas:
- Rotar el password requiere `rekey` del archivo + sincronizar la nueva en todos los que la tenian.
- No hay auditoría de quién leyó el archivo.
- `git diff` sobre `prod.yml` es ilegible.

### Opción B — SOPS + KMS

1. Encriptas el archivo con `sops --encrypt --kms arn:aws:kms:... prod.yml > prod.enc.yml`.
2. Commiteas `prod.enc.yml`. Las keys YAML están en claro, los valores encriptados individualmente.
3. El runner tiene permiso IAM `kms:Decrypt` sobre la KMS key.
4. Ansible lo lee con `community.sops.sops` lookup o con `sops --decrypt` + extra-vars.

Mejoras sobre A:
- `git diff` legible por key.
- Rotación = re-encrypt con nueva KMS key (no hay password que distribuir).
- Auditoría: KMS registra cada `Decrypt` en CloudTrail.
- Multi-recipient: el mismo archivo cifrado para N keys (p. ej. una por equipo).

### Opción C — Lookup directo a AWS Secrets Manager

1. **Nada** del secreto vive en el repo.
2. En la tarea Ansible:
   ```yaml
   db_password: "{{ lookup('amazon.aws.aws_secret', 'prod/db/password', region='eu-west-1') }}"
   ```
3. El runner tiene `secretsmanager:GetSecretValue` sobre ese ARN.

Mejoras sobre B:
- El secreto rota automáticamente desde SM (Lambda rotation) sin tocar el repo.
- Un dev con acceso al repo **nunca** ve el valor, ni cifrado.
- El valor nunca pasa por el disco del runner (está en memoria del proceso).

### Opción D — External Secrets Operator (si la app está en K8s)

1. En el repo del cluster declaras:
   ```yaml
   apiVersion: external-secrets.io/v1
   kind: ExternalSecret
   metadata:
     name: db-password
   spec:
     refreshInterval: 1h
     secretStoreRef:
       name: aws-sm
       kind: ClusterSecretStore
     target:
       name: db-password
     data:
       - secretKey: password
         remoteRef:
           key: prod/db/password
   ```
2. ESO ve el CRD, llama a AWS SM, crea el `Secret` K8s `db-password` cada hora.
3. Tu Deployment monta el `Secret` como env var o volume.
4. Ansible **no interviene** en el runtime del secreto — solo lo usó quien provisionó el cluster y el `ClusterSecretStore`.

## 3. Matriz de decisión

| Escenario | A `ansible-vault` | B SOPS | C Lookup directo | D ESO |
|-----------|-------------------|--------|------------------|-------|
| Un playbook pequeño, 1 secreto, un ingeniero | SI | — | — | — |
| Repo compartido por un equipo, diffs importantes | — | SI | — | — |
| Prod serio con rotación automática, bare metal/EC2 | — | — | SI | — |
| App corriendo en Kubernetes | — | — | solo si lo usas desde Ansible al provisionar nodos | SI |
| Compliance: auditoría de accesos obligatoria | NO | parcial (via KMS logs) | SI | SI |
| Zero conectividad al runner (airgapped) | SI | SI (si KMS local) | NO | NO |

## 4. Antipatrones vistos en el mundo real

1. Commitear la vault password junto al archivo encriptado "para no olvidarla". Perdiste todo lo que te daba vault.
2. Usar `ansible-vault` sin `no_log: true` en los tasks que la consumen → el secreto aparece en el stdout del playbook y de ahi al log del CI.
3. Un solo vault password para dev, stg y prod → cualquier dev tiene prod.
4. SOPS cifrando con PGP sin backup de la private key → el día que esa persona se va, los secretos son inrecuperables.
5. ESO en K8s pero el `ClusterSecretStore` apunta con credenciales **long-lived** (user IAM) en vez de IRSA/Workload Identity → el mismo problema de rotación que teníamos.

## 5. Regla práctica

- **Empieza simple**: `ansible-vault` si estás solo o en un equipo pequeño con un solo entorno.
- **Escala**: SOPS cuando el equipo crece y los diffs importan.
- **Prod serio**: lookup directo a secret manager.
- **K8s**: External Secrets Operator — es el estandar de facto.
- **Nunca** mezcles secretos reales en los ejemplos del repo. Usa `fake-...`.
