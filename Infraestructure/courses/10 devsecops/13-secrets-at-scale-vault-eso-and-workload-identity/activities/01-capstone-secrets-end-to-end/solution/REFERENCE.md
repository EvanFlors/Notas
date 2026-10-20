# REFERENCE — sec-13-01-capstone-secrets-end-to-end

> Explica **por qué** cada pieza del capstone está donde está. Los manifests completos están en `solution/manifests/`.

## Decisión 1 — Vault en Docker, no en el cluster

Para un laboratorio local es más instructivo ver Vault como un servicio **externo** al cluster: enfatiza que Vault es la *source of truth* y que ESO es un *puente*. En producción Vault suele vivir en el cluster (HA 3 nodos + auto-unseal), pero esa topología oscurece el flujo pedagógico. El contenedor comparte la red `kind` para que la IP interna de Vault sea alcanzable desde el API server.

## Decisión 2 — ESO vía Helm, no manifests crudos

El chart oficial instala CRDs, webhooks, cert-controller y RBAC correctamente. Reproducirlo a mano requeriría ~15 manifests. En producción el chart se gestiona con Argo CD/Flux; aquí, `helm upgrade --install` directo basta.

## Decisión 3 — `ClusterSecretStore` en vez de `SecretStore`

`SecretStore` es namespaced. `ClusterSecretStore` es cluster-wide. Elegimos el cluster-wide porque:

- Un solo backend Vault sirve a múltiples namespaces (`payments`, `billing`, `batch`…).
- Evita duplicar la configuración de autenticación en cada namespace.
- Trade-off: cualquier `ExternalSecret` del cluster puede referenciarlo. Mitigado por las policies de Vault (el role `eso-payments` solo lee `kv/payments/*`).

## Decisión 4 — El role de Vault se enlaza al SA de ESO, no al SA del consumer

El `ClusterSecretStore` se autentica contra Vault **con el SA del operator** (`external-secrets/external-secrets`), no con el SA del Pod consumer (`payments/payments-app`). Razón:

- ESO es quien lee del backend y escribe el `Secret` K8s.
- El Pod consumer **no** habla con Vault directamente; consume el `Secret` K8s.
- Si vinculases el role al SA del consumer, cada microservicio necesitaría su propio flujo de auth Vault — se pierde el valor de ESO como *puente declarativo*.

Si quieres que **cada** servicio tenga su propio aislamiento Vault, puedes crear un `SecretStore` por namespace con un SA dedicado y un role Vault específico. Más seguro, más YAML.

## Decisión 5 — `creationPolicy: Owner`

ESO crea el `Secret` K8s y lo borra si se elimina el `ExternalSecret`. Es GitOps-friendly: el `ExternalSecret` en Git es el *source of truth* del *qué* y *dónde*, y Argo/Flux pueden reconciliar.

Alternativa: `creationPolicy: Merge` si convive con un `Secret` existente (p. ej. Helm chart ya crea un `Secret` para la DB y queremos **añadir** una clave).

## Decisión 6 — `refreshInterval: 30s`

Para laboratorio es ágil. En producción el valor típico está entre **1m y 15m**:

- Más corto = reflejo rápido de rotaciones + más carga sobre Vault.
- Más largo = ventana de desfase; mitigable con un trigger manual (`kubectl annotate externalsecret ... force-sync=$(date +%s)`).

Para secretos que **cambian frecuentemente** (dynamic creds) el patrón correcto es **no** usar `ExternalSecret` para ese secret — usar el SDK Vault o el Vault Agent sidecar directamente. ESO brilla con secretos **estáticos** o rotados en el orden de días.

## Decisión 7 — El valor **nunca** aparece en los manifests

Los manifests entregados tienen:

- `secret-store.yaml` — URL + role (ambos metadatos, no secretos).
- `external-secret.yaml` — path + property (metadatos del *dónde*).
- `consumer.yaml` — `secretKeyRef` (metadato del *nombre*).

`grep -R 'sk_test_' starter/manifests/` **no debe** devolver nada. El validador lo comprueba. Esta es la propiedad invariante del capstone: *lo que vive en Git describe demanda; el valor nunca sale de Vault excepto para materializarse en runtime*.

## Decisión 8 — No `reloader`

El capstone deliberadamente **no** instala `stakater/reloader`. Al cambiar el valor en Vault, el `Secret` K8s se actualiza (lo verificas), pero el Pod sigue con el valor viejo en su env var. Es un hallazgo pedagógico importante: *actualizar un `Secret` no actualiza los procesos que ya lo leyeron*. En producción añadirías `reloader` o montarías el secret como fichero + señal SIGHUP a la app.

Se trabaja en la **extensión 3** de la actividad.

## Qué queda pendiente en producción (fuera del capstone)

- **TLS** entre Pod → Vault. Aquí es `http://` dev. En prod, Vault + ingress con cert válido.
- **HA Vault** con Raft storage + auto-unseal via KMS. 3 nodos mínimo.
- **Audit log** apuntando a sink inmutable (S3 Object Lock).
- **IRSA / GKE WI** para que el nodo + ESO + consumer tengan identidad cloud nativa.
- **Dynamic secrets** reales (DB creds con TTL = 1h) — ESO soporta `database/` también vía `generators` CRD.
- **Rotación del root token** inicial (en dev no aplica — hay `token=root` fijo).
