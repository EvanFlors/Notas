# Ejemplo 03 — External Secrets Operator (walkthrough; sin instalación)

## Concepto que demuestra

El patrón de **secret manager externo**: el cluster deja de ser la *fuente de verdad* de los secretos; la fuente vive en Vault / AWS Secrets Manager / GCP Secret Manager / Azure Key Vault, y un controller sincroniza (o monta directamente).

Comparamos las tres alternativas más usadas: **External Secrets Operator (ESO)**, **Secrets Store CSI Driver** y **Vault Agent Injector**.

Este ejemplo es un **walkthrough**: no instalamos nada real para evitar depender de un backend cloud. Lees los manifiestos, entiendes el flujo, y sabrás reconocer cuándo tiene sentido cada uno.

## Contexto

Ya viste (ejemplo 02) que un Secret nativo de K8s es base64 cleartext en etcd, y que incluso con `EncryptionConfiguration` la rotación la haces tú a mano (`kubectl replace`). Los secret managers externos resuelven dos cosas:

1. **Fuente de verdad fuera del cluster** — rotación, auditoría, versionado, políticas de acceso ya existentes.
2. **Ciclo de vida automático** — refresh cada N minutos, rotación atómica, sin tocar el repo de manifests.

## Objetivo

Al terminar sabrás:

- Qué `SecretStore` y `ExternalSecret` resuelven (y por qué son un patrón, no una herramienta puntual).
- Diferenciar ESO vs CSI Driver vs Vault Injector en términos operativos.
- Elegir el default razonable para un equipo pequeño.

## Prerrequisitos

- Haber hecho el ejemplo 02.
- Lectura solamente: no se instala nada en este ejemplo.

## 1. External Secrets Operator (ESO)

**Dos CRDs** definen el patrón:

- `SecretStore` o `ClusterSecretStore` — cómo autenticar con el backend.
- `ExternalSecret` — qué secretos pedir y cómo mapearlos.

```yaml
# ClusterSecretStore apuntando a AWS Secrets Manager (requiere IRSA ya configurado)
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-sm
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: eso-sa
            namespace: external-secrets
---
# El ExternalSecret vive en el namespace de la app
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db
  namespace: app
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-sm
    kind: ClusterSecretStore
  target:
    name: db                       # el Secret nativo que ESO materializa
    creationPolicy: Owner
    template:
      type: Opaque
  data:
    - secretKey: password          # clave en el Secret resultante
      remoteRef:
        key: prod/app/db           # path en AWS SM
        property: password         # campo dentro del JSON de ese secret
```

**Resultado**: cada hora, ESO llama a AWS SM, obtiene `prod/app/db`, extrae `.password`, y escribe/actualiza el `Secret` nativo `db` en el namespace `app`. La app lee ese Secret como siempre (volumen montado).

**Ventajas**:

- La app no cambia (sigue leyendo un Secret nativo).
- Rotar en AWS SM se refleja sin despliegue.
- Multi-backend: Vault, AWS, GCP, Azure, 1Password, GitLab Variables, etc.

**Trade-off**: el Secret nativo sigue existiendo en etcd. Si no activaste `EncryptionConfiguration`, sigues con base64 cleartext ahí. ESO reduce *el riesgo humano* (nadie escribe passwords a mano) pero no elimina el riesgo de etcd a menos que combines con encryption at rest o uses CSI Driver.

## 2. Secrets Store CSI Driver

Monta secretos del backend **directamente como archivos efímeros** en un volumen CSI. No crea un `Secret` nativo por default (opción `syncSecret.enabled: true` si lo necesitas para controllers que esperan `secretKeyRef`).

```yaml
# SecretProviderClass: declara qué secretos del backend se montarán
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: db
  namespace: app
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "prod/app/db"
        objectType: "secretsmanager"
        jmesPath:
          - path: "password"
            objectAlias: "db-password"
---
apiVersion: v1
kind: Pod
metadata:
  name: app
  namespace: app
spec:
  serviceAccountName: app-sa
  containers:
    - name: app
      image: app:1.2.3
      volumeMounts:
        - name: secrets
          mountPath: /mnt/secrets
          readOnly: true
  volumes:
    - name: secrets
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: db
```

**Ventajas**:

- No hay Secret nativo en etcd (si no activas `syncSecret`).
- El file se refresca al re-mount del volumen (depende del provider y la configuración de rotation reconciler).

**Trade-off**:

- Hay que instalar el driver *y* el provider del cloud. Más piezas móviles.
- Si quieres controllers que esperan `secretKeyRef` (p. ej. Postgres operator con una password), igual necesitas `syncSecret.enabled: true` y vuelves al escenario de Secret nativo en etcd.

## 3. Vault Agent Injector

Un `MutatingAdmissionWebhook` de HashiCorp Vault que inyecta un **sidecar Vault Agent** a Pods que llevan anotaciones específicas. El sidecar hace login a Vault (con una ServiceAccount token), obtiene los secretos y los **renderiza con plantillas Go** en un `emptyDir` compartido con el contenedor principal.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "app"
    vault.hashicorp.com/agent-inject-secret-db: "database/creds/app"
    vault.hashicorp.com/agent-inject-template-db: |
      {{- with secret "database/creds/app" -}}
      DB_PASSWORD={{ .Data.password }}
      {{- end }}
spec:
  serviceAccountName: app
  containers:
    - name: app
      image: app:1.2.3
      # /vault/secrets/db queda poblado por el sidecar antes de que la app arranque
```

**Ventajas**:

- Lease dinámico de Vault: credenciales de DB generadas on-demand con TTL, revocables.
- No pasa por etcd.
- Plantillas Go muy expresivas (concat, encoding, formato propio).

**Trade-off**:

- Sidecar por Pod: overhead CPU/memoria y una capa más en el blast radius.
- Específico de Vault (no cambias de proveedor sin reescribir).

## 4. Decisión: ¿cuál para el equipo del capstone?

| Criterio | ESO | CSI Driver | Vault Injector |
|----------|-----|------------|----------------|
| Hay Secret nativo en etcd | Sí | No (opcional) | No |
| App no cambia | Sí (lee Secret como siempre) | Si usas `syncSecret` sí; si no, lee archivos nuevos | Lee `/vault/secrets/<name>` |
| Rotación automática | Sí (poll) | Sí (reconciler) | Sí (lease TTL) |
| Multi-backend | Sí (muchos) | Sí (muchos, vía providers) | Solo Vault |
| Overhead en cluster | 1 controller | 1 driver per nodo + 1 provider | 1 sidecar por Pod |
| Learning curve | Baja | Media | Alta |
| Caso típico | PyMEs/startups en cloud managed | Compliance estricta (no Secret en etcd) | Shops ya en Vault con secretos dinámicos |

**Para el capstone**: ESO + `EncryptionConfiguration` en el apiserver (si self-hosted) o cifrado at-rest nativo del cloud managed (EKS/GKE/AKS).

## Lo que acabas de ver, resumido

- Los tres patrones comparten objetivo (sacar el Secret de etcd como fuente de verdad) y difieren en forma.
- ESO es el default razonable; CSI Driver es más estricto; Vault Injector es ideal si ya tienes Vault y quieres dynamic secrets.
- Nunca es "o esto o cifrado at-rest". Combinarlos es el estado del arte: Secret manager externo + encryption at rest + RBAC `get secrets` restringido.

## Lecturas

- ESO docs: <https://external-secrets.io/>
- Secrets Store CSI Driver: <https://secrets-store-csi-driver.sigs.k8s.io/>
- Vault Agent Injector: <https://developer.hashicorp.com/vault/docs/platform/k8s/injector>
- Encryption at rest: <https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/>
