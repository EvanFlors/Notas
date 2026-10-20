# Actividad 01 — Capstone: Vault + ESO + Pod sin ningún secreto estático en Git

## 1. Identificación

- **ID:** `sec-13-01-capstone-secrets-end-to-end`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-13-secrets-at-scale-vault-eso-and-workload-identity`
- **Dificultad:** advanced
- **Duración estimada:** 2–3 h
- **Tipo:** mini-project (depende del `example-02`; recomendable haber corrido `example-01` y `example-02` antes)

## 2. Contexto

Monta end-to-end el flujo que la lección dibuja en §5:

```
   Vault dev (Docker)
         │ (role: payments)
         ▼
   ESO (Helm en kind)
         │ (ExternalSecret cada 30s)
         ▼
   Secret K8s payments-stripe
         │
         ▼
   Deployment payments-app (consumer)
     env: STRIPE_API_KEY  ← secretKeyRef
```

El **requisito duro** del capstone: en los manifests que entregas (`starter/manifests/*.yaml`) **no** debe aparecer ningún valor de secreto. Solo *qué* se necesita y *dónde* vive. El valor existe únicamente dentro de Vault y, por efecto de ESO, dentro del `Secret` K8s en runtime.

## 3. Objetivos

- Levantar Vault + kind + ESO + consumer end-to-end.
- Completar los TODOs en `starter/manifests/*.yaml`.
- Verificar que el `Secret` K8s se materializa con el valor correcto.
- Verificar que el Pod consumer expone el valor en una env var tras rolling restart.
- Demostrar rotación en vivo: cambiar el valor en Vault y ver el `Secret` actualizarse.

## 4. Prerrequisitos

- Herramientas: `docker`, `kind`, `kubectl`, `helm`, `vault` CLI, `jq`.
- Haber leído la lección completa, en especial §5 y §7.
- Haber ejecutado al menos `example-01` para entender el flujo de `kubernetes` auth.

**Costos:** ninguno (todo local).

## 5. Instrucciones

### 5.1 Scratch dir y estado inicial

```bash
export WORK=/tmp/sec-13-capstone
mkdir -p "$WORK"
```

Todos los scripts del `starter/` escriben estado efímero bajo `$WORK` o en Docker/kind. Al final, `cleanup.sh` lo deja todo limpio.

### 5.2 Levanta el entorno (scripts del starter, en orden)

```bash
cd <ruta-repo>/courses/devsecops/13-secrets-at-scale-vault-eso-and-workload-identity/activities/01-capstone-secrets-end-to-end/starter

./01-start-vault.sh         # Docker: vault:1.15 dev mode, token=root
./02-create-cluster.sh      # kind: cluster sec-13-capstone
./03-install-eso.sh         # helm install external-secrets en namespace external-secrets
./04-bootstrap-vault.sh     # Habilita kv-v2 + kubernetes auth + roles + policies + semilla kv/payments/stripe
```

Verifica después de cada paso:

- `vault status` responde (via `VAULT_ADDR=http://127.0.0.1:8200`, `VAULT_TOKEN=root`).
- `kubectl --context kind-sec-13-capstone get nodes` muestra el nodo Ready.
- `kubectl -n external-secrets get pods` muestra ESO Running.
- `vault kv get kv/payments/stripe` devuelve `api_key=sk_test_INIT`.

### 5.3 Completa los manifests

Edita (sin cambiar el nombre de los recursos ni los paths referenciados):

- `starter/manifests/secret-store.yaml` — reemplaza los `# TODO:` por:
  - `spec.provider.vault.server` con la URL del Vault visible desde el cluster (el `04-bootstrap-vault.sh` imprime el valor correcto; también puedes recalcularlo con `docker inspect`).
  - `spec.provider.vault.auth.kubernetes.role` con `eso-payments`.
- `starter/manifests/external-secret.yaml` — reemplaza los `# TODO:` por:
  - `spec.secretStoreRef.name = vault-dev`.
  - `spec.target.name = payments-stripe`.
  - `spec.data[0].remoteRef.key = payments/stripe` y `property = api_key`.
- `starter/manifests/consumer.yaml` — reemplaza el `# TODO:` por un `secretKeyRef` que apunte al `Secret` `payments-stripe`, clave `STRIPE_API_KEY`.

**Prohibido**: escribir el valor `sk_test_...` en cualquier manifest. El validador lo checkea.

### 5.4 Aplica y verifica

```bash
kubectl --context kind-sec-13-capstone apply -f starter/manifests/
sleep 20
kubectl --context kind-sec-13-capstone get clustersecretstore vault-dev
# STATUS = Valid
kubectl --context kind-sec-13-capstone -n payments get externalsecret payments-stripe
# STATUS = SecretSynced
kubectl --context kind-sec-13-capstone -n payments get secret payments-stripe -o jsonpath='{.data.STRIPE_API_KEY}' | base64 -d; echo
# → sk_test_INIT
kubectl --context kind-sec-13-capstone -n payments rollout status deployment/payments-app
kubectl --context kind-sec-13-capstone -n payments exec deploy/payments-app -- printenv STRIPE_API_KEY
# → sk_test_INIT
```

### 5.5 Demuestra rotación

```bash
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root
vault kv put kv/payments/stripe api_key=sk_test_ROTATED
sleep 40
kubectl --context kind-sec-13-capstone -n payments get secret payments-stripe -o jsonpath='{.data.STRIPE_API_KEY}' | base64 -d; echo
# → sk_test_ROTATED
```

### 5.6 Entregable

- Manifests editados **sin valores de secreto**.
- El `Secret` K8s `payments-stripe` en el cluster con `STRIPE_API_KEY` correctamente materializado.
- Deployment `payments-app` corriendo y exponiendo la env var `STRIPE_API_KEY`.

## 6. Validación

```bash
bash tests/validate.sh
```

El validador:

- **SKIP gracefully** si falta cualquiera de `docker`, `kind`, `kubectl`, `helm`, `vault`, `jq`.
- Verifica que `starter/manifests/*.yaml` **no** contienen valores de secreto literales.
- Verifica que el cluster `sec-13-capstone` existe y ESO está Running.
- Verifica que `ClusterSecretStore` reporta `Valid` y `ExternalSecret` reporta `SecretSynced`.
- Verifica que el `Secret` K8s existe y el valor de `STRIPE_API_KEY` coincide con el de Vault.
- Verifica que el Pod consumer expone la env var.

Si el validador falla por "cluster not found" o "ESO not installed", **no** es un bug del capstone: ejecuta los scripts `01-` a `04-` del starter.

## 7. Criterios de aceptación

- **Funcionalidad:** validador pasa (todas las comprobaciones no-SKIP en verde).
- **Seguridad:** `grep -R 'sk_test_' starter/manifests/` no devuelve resultados.
- **Reproducibilidad:** ejecutando `cleanup.sh` + los 4 scripts + `kubectl apply` + validador, otro ingeniero reproduce el estado en < 15 min.
- **Mantenibilidad:** manifests son YAML válido con nombres descriptivos.

## 8. Preguntas de reflexión

1. ¿Qué pasa si rotas la raíz de Vault (`vault token revoke -self` con el root) mientras el `ExternalSecret` está activo? ¿Qué sucede en el siguiente refresh?
2. ¿Por qué el `role` de Vault enlaza al SA `external-secrets` en namespace `external-secrets` y **no** al SA de `payments-app`?
3. Si quisieras que el Pod reiniciara automáticamente cuando el `Secret` cambia, ¿qué pieza externa añadirías? ¿Cuáles son sus trade-offs frente a montar el secreto como fichero?
4. ¿Qué cambiaría en los manifests si usaras AWS Secrets Manager como backend en vez de Vault? ¿Cuánto es realmente portable?
5. En producción, ¿cuánto bajarías el `refreshInterval`? ¿Qué costes aparecen al bajarlo demasiado?

## 9. Extensiones

- Añade un segundo `ExternalSecret` para `kv/payments/datadog` y un segundo deployment.
- Convierte el consumer a **dynamic DB creds** apuntando a un Postgres en Docker (combina `example-03` con esta pipeline).
- Instala `stakater/reloader` y confirma que el Deployment hace rollout automático al cambiar el `Secret`.

## 10. Limpieza

```bash
./starter/cleanup.sh
```

Elimina el cluster `kind`, el contenedor `sec-13-vault` y `/tmp/sec-13-capstone`.
