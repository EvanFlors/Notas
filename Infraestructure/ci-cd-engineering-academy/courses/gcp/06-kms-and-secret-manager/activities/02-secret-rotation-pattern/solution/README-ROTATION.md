# Secret Manager — rotación con solape (solución de referencia)

Acompaña a `main.tf`, `iam-binding-secret-accessor.json` y `rotator.py`. Documenta por qué el patrón es así y qué pasa si lo haces diferente.

## Ventana de solape

La **ventana de solape** es el periodo durante el cual la versión antigua del secret sigue `ENABLED` después de haber creado la nueva. Es imprescindible porque:

- Los consumidores (Cloud Run, GKE, workers, scripts) **cachean** el valor en RAM entre peticiones. Si desactivas la versión vieja inmediatamente, cualquier consumidor que aún tenga la vieja cacheada **falla con `PERMISSION_DENIED`** en su siguiente autenticación contra el proveedor externo.
- Hay conexiones vivas (DB, SMTP, proveedor SaaS) que se autenticaron hace minutos y seguirán usando el token viejo hasta reconectar.
- El redeploy de los servicios Cloud Run con `--set-secrets=X=secret:latest` solo refresca al **crear una nueva revisión**; las revisiones vivas mantienen la referencia resuelta al momento de su arranque.

Ventana recomendada: **mínimo 2× el TTL de caché del consumidor** (si cacheas 1 hora, da 2 horas). Para rotación programada (nocturna), 24 h es un valor conservador. Si pones `OVERLAP_SECONDS = 0`, los servicios que resolvieron `:latest` antes de la rotación empezarán a fallar en cuanto el nuevo valor se propague al proveedor externo y el viejo se marque `DISABLED`.

En `rotator.py` el solape es `0.05 s` solo para que el test corra rápido. En producción eso **no es seguro**.

## Replicación

El Secret se declara con `replication { auto {} }`. Razones:

- **Más barato** operativamente: no decides regiones, no revisas el estado por región, no reconfiguras cuando GCP añade regiones nuevas.
- **Mayor resiliencia**: GCP replica a múltiples regiones del continente apropiado y resuelve lecturas desde la más cercana.

Cuándo usar `user-managed` en su lugar:

- Compliance de residencia (p. ej. "este secreto solo puede vivir en `europe-west1` y `europe-west4`").
- Quieres aplicar **CMEK por región** (`user-managed` permite declarar una `customer_managed_encryption.kms_key_name` por réplica; `auto` no).

Para una API key de un proveedor global, `auto` es siempre la elección correcta.

## Modelo de acceso

El principal consumidor (`sa-run-app@demo-secret-example.iam.gserviceaccount.com`) recibe `roles/secretmanager.secretAccessor` **sobre el secret concreto**, nunca sobre el project. Razones:

- Dar `secretAccessor` a nivel project daría acceso a **todos** los secretos del project. Violación directa del principio de menor privilegio.
- El rol `secretAccessor` otorga únicamente `secretmanager.versions.access` (leer el valor de una versión). No permite listar, no permite escribir, no permite rotar.
- Para la rotación en sí se usa una **segunda** service account distinta (p. ej. `sa-rotator@...`) con `roles/secretmanager.secretVersionManager` sobre el secret, para poder publicar versiones nuevas y marcar como `DISABLED` las viejas.

El flujo de resolución habitual:

1. Cloud Run arranca una revisión con `--set-secrets=API_KEY=external-api-key:latest`.
2. El runtime consulta Secret Manager usando el **service account del servicio**.
3. Secret Manager verifica el binding `secretAccessor` y devuelve el valor de la última versión `ENABLED`.
4. La app lo lee de env var o de disco y lo usa.

## Rotación en el proveedor externo

El rotator real (Cloud Function o Cloud Run job disparado por el topic de Pub/Sub) hace algo así:

```python
def on_rotation_event(event):
    # 1. Pedir nueva credencial al proveedor externo (Stripe, SendGrid...).
    new_key = provider.create_api_key(name=f"rotated-{now()}")

    # 2. Validar que la nueva key funciona (healthcheck minimo).
    assert provider.ping(api_key=new_key).ok

    # 3. Publicar nueva version en Secret Manager.
    client.add_secret_version(
        parent=secret_name,
        payload={"data": new_key.encode()},
    )

    # 4. Dejar que el solape haga su trabajo. En este punto, los nuevos
    #    consumidores que resuelvan ":latest" ya reciben la nueva.
    schedule_task(delay=OVERLAP_SECONDS, fn=disable_old_version)
```

Y en una tarea posterior:

```python
def disable_old_version(previous_version_name):
    # 5. Marcar la vieja como DISABLED en Secret Manager.
    client.disable_secret_version(name=previous_version_name)

    # 6. Revocar la credencial correspondiente en el proveedor externo.
    provider.delete_api_key(name=extract_provider_id(previous_version_name))
```

Puntos clave:

- La versión anterior solo se desactiva **después** del solape.
- Siempre se **valida la nueva key** antes de dejarla como `latest`.
- La revocación en el proveedor externo va **después** del `DISABLED` en Secret Manager (orden inverso crea una ventana de fallos).
- `rotation_period` + `topic` en el Secret son lo que dispara este flujo periódicamente. El topic de **Pub/Sub** recibe un mensaje cada vez que toca rotar; el rotator está suscrito.
- Los consumidores que leen con `:latest` recogen el valor nuevo al próximo redeploy (o inmediatamente en caliente si tu app re-consulta Secret Manager periódicamente). Los que leen con `:3` (versión fija) **no se enteran de la rotación** — es intencional para builds reproducibles o rollbacks atómicos.
