# Actividad 02 — Secret Manager con rotación (plan + rotador local)

## 1. Identificación

- **ID:** `gcp-06-02-secret-rotation-pattern`
- **Tecnología:** `gcp`
- **Módulo:** `gcp-06-kms-and-secret-manager`
- **Dificultad:** intermediate
- **Duración estimada:** 60–75 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Un servicio externo (p. ej. Stripe, SendGrid) emite API keys que el equipo quiere rotar automáticamente cada 30 días. Vas a escribir el **plan Terraform** del `Secret` en Secret Manager, el **IAM binding** para el servicio consumidor y un **rotator local** en Python que simule el ciclo *create-new-version → overlap → disable-old* sin hablar con GCP.

**No hay project GCP, no se aplica Terraform y no se envía nada a Secret Manager real.** Todos los valores son ficticios (`fake-sk-...`). Nunca uses una API key real.

## 3. Objetivos

Al terminar deberías poder:

- Escribir `google_secret_manager_secret` con `replication.auto {}` y `rotation { rotation_period, next_rotation_time, topic }`.
- Escribir `google_secret_manager_secret_version` con un `secret_data` **ficticio** (no un valor real).
- Escribir `google_pubsub_topic` destino de los eventos de rotación.
- Escribir el IAM binding JSON del principal consumidor con `roles/secretmanager.secretAccessor` sobre el secret concreto.
- Implementar un rotator que mantenga una ventana de solape (`OVERLAP_SECONDS`) antes de desactivar la versión anterior.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§5, §6, §7).
- Haber revisado `../../examples/02-secret-manager-mount-in-cloud-run/`.
- Herramientas locales: `bash`, `jq`, `python3` ≥ 3.9. **No se requiere** `terraform` CLI, `gcloud`, ni la librería `google-cloud-secret-manager`.

**Costos**: ninguno. Todo corre en tu máquina local.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gcp-06-secret
cd /tmp/gcp-06-secret
```

### 5.2 Escribe `main.tf`

El validador espera **exactamente** estos recursos:

- `google_pubsub_topic` con nombre local `secret_rotation` y `name = "topic-secret-rotation"`.
- `google_secret_manager_secret` con nombre local `api_key`, `secret_id = "external-api-key"`, bloque `replication { auto {} }`, y bloque `rotation { rotation_period = "2592000s"; next_rotation_time = <RFC3339>; topic = google_pubsub_topic.secret_rotation.id }`.
- `google_secret_manager_secret_version` con `secret_data` empezando por `fake-sk-` (ficticio).
- `google_secret_manager_secret_iam_member` con `role = "roles/secretmanager.secretAccessor"` y `member = "serviceAccount:sa-run-app@demo-secret-example.iam.gserviceaccount.com"`.

Variables sugeridas: `project_id = "demo-secret-example"`, `region = "europe-west1"`. **No** uses project IDs reales. **No** uses valores de secretos reales.

### 5.3 Escribe `iam-binding-secret-accessor.json`

JSON con la política mínima:

```json
{
  "bindings": [
    {
      "role": "roles/secretmanager.secretAccessor",
      "members": [
        "serviceAccount:sa-run-app@demo-secret-example.iam.gserviceaccount.com"
      ]
    }
  ],
  "etag": "BwAAAA==",
  "version": 1
}
```

El validador comprueba JSON válido, rol correcto y miembro con el patrón `serviceAccount:<name>@<project>.iam.gserviceaccount.com`.

### 5.4 Escribe `rotator.py`

Debe ser un script Python ejecutable que simule **en memoria** el ciclo completo de rotación de un secret con **ventana de solape**. Debe:

1. Partir de un estado inicial: `versions = [ { "id": 1, "value": "fake-sk-v1-xxxx", "state": "ENABLED" } ]`.
2. Ejecutar `rotate()`:
   - Genera un valor nuevo `fake-sk-v<N>-<random>` (nunca un secreto real).
   - Crea una **nueva versión** `ENABLED`.
   - Marca el `OVERLAP_SECONDS` que debe pasar antes de desactivar la anterior.
3. Ejecutar `settle()`:
   - Transcurrido el solape, marca la versión anterior como `DISABLED`.
   - (Opcional) Pasado un segundo plazo, la marca como `DESTROYED`.
4. Imprimir el estado final en formato legible y una línea final:
   `ROTATION_OK: new=<version_id> previous=<state>`.
5. **Falla con `sys.exit(1)`** si detecta que el nuevo valor no empieza por `fake-` (defensa contra pegar un valor real por error).

El validador ejecuta `python3 rotator.py` y comprueba:
- `exit code == 0`.
- `ROTATION_OK: new=2 previous=DISABLED` aparece en stdout.
- Ninguna línea del stdout contiene patrones típicos de secretos reales (ver §7).

### 5.5 Escribe `README-ROTATION.md`

Secciones obligatorias (headings markdown):

- `## Ventana de solape` — por qué el solape es imprescindible, qué pasa si lo saltas.
- `## Replicación` — `automatic` vs `user-managed`, justificación.
- `## Modelo de acceso` — por qué `secretAccessor` sobre el secret concreto, no sobre el project.
- `## Rotación en el proveedor externo` — pseudocódigo de "crear nueva API key en el proveedor, probarla, publicar nueva versión, revocar la vieja al expirar el solape".

Debe mencionar explícitamente `Pub/Sub`, `rotation_period`, `secretAccessor` y `latest`. **No** llames al archivo `ANALYSIS.md`.

### 5.6 Entregables

```
/tmp/gcp-06-secret/
├── main.tf
├── iam-binding-secret-accessor.json
├── rotator.py
└── README-ROTATION.md
```

## 6. Resultado esperado

- Los 4 archivos existen.
- `main.tf` declara los 4 recursos y los atributos obligatorios; **todo** `secret_data` empieza por `fake-sk-`.
- `iam-binding-secret-accessor.json` parsea con `jq .` y cumple la estructura.
- `python3 rotator.py` corre sin error, imprime `ROTATION_OK`, no filtra patrones de secretos reales.
- `README-ROTATION.md` tiene las 4 secciones y menciona `Pub/Sub`, `rotation_period`, `secretAccessor`, `latest`.

## 7. Guardias contra secretos reales

El validador rechaza (`FAIL`) cualquier aparición de estos patrones (son prefijos reales conocidos):

- `sk_live_` (Stripe live)
- `sk_test_` (Stripe test — ambiguo, también se rechaza por consistencia)
- `AKIA[0-9A-Z]{16}` (AWS Access Key ID)
- `ghp_[A-Za-z0-9]{30,}` (GitHub Personal Access Token)
- `xoxb-` (Slack bot token)
- `AIza[0-9A-Za-z_-]{30,}` (Google API key)

Usa **siempre** `fake-sk-...` o similares.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gcp-06-secret
```

El validador comprueba estructura, ejecuta `rotator.py`, y busca patrones de secretos reales en todos los archivos entregables.

## 9. Criterios de aceptación

- **Funcionalidad**: validador pasa en verde.
- **Correctitud sintáctica**: HCL parseable, JSON válido, Python ejecutable.
- **Correctitud conceptual**: ciclo de rotación con solape documentado y simulado.
- **Seguridad**: cero secretos reales en el entregable.

## 10. Preguntas de reflexión

1. ¿Qué pasa si pones `OVERLAP_SECONDS = 0` y el servicio tenía la versión `N-1` cacheada en RAM?
2. ¿Puedes rotar un secret sin reiniciar el servicio Cloud Run? ¿Qué cambia si consumes con `:latest` vs con `:3`?
3. ¿Por qué `replication.auto` suele ser preferible a `user-managed`? ¿Cuándo *no* lo es?
4. ¿Qué principal publica el mensaje al topic de rotación? ¿Qué permiso necesita *él* para hacerlo?
5. ¿Cómo auditarías quién leyó la versión `3` del secret y cuándo?

## 11. Extensiones

- Añade un segundo consumidor (`sa-worker-app@...`) con otro `IAM binding` sobre el mismo secret.
- Añade una `google_cloud_scheduler_job` que publique manualmente al topic cada 15 días.
- Extiende `rotator.py` para mantener historial completo y simular 5 rotaciones consecutivas.

## 12. Limpieza

```bash
rm -rf /tmp/gcp-06-secret
```

No hay infraestructura que detener.
