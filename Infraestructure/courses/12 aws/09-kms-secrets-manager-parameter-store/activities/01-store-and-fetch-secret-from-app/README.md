# Actividad 01 — Guardar y resolver un secreto desde una app (envelope encryption)

## 1. Identificación

- **ID:** `aws-09-01-store-and-fetch-secret-from-app`
- **Tecnología:** `aws`
- **Módulo:** `aws-09-kms-secrets-manager-parameter-store`
- **Dificultad:** intermediate
- **Duración estimada:** 60–90 min
- **Tipo:** guided-lab (independiente de la actividad 02)

## 2. Contexto

Vamos a reproducir, contra **LocalStack**, el flujo real de una app `checkout` que:

1. Resuelve su password de DB desde **Secrets Manager**.
2. Resuelve su endpoint de DB desde **SSM Parameter Store** (`SecureString`).
3. Cifra un *payload* local (p. ej. una card token de prueba) con **envelope encryption** usando una CMK customer-managed.

**Todos los valores son fake y están etiquetados como tal.** Nunca uses secretos reales en esta actividad.

## 3. Objetivos

- Crear una **CMK** y una **key policy** estructuralmente correcta (validada con `jq`).
- Guardar un secret y un `SecureString` cifrados con esa CMK.
- Implementar `envelope_encrypt(payload) -> blob` y `envelope_decrypt(blob) -> payload` con `boto3` + `cryptography` (AES-GCM).
- Escribir `app.py` que simule la lectura al arranque: resuelve el secret y el parámetro, loguea (sin imprimir el valor) y escribe un `app.log`.

## 4. Prerrequisitos

- `python3` ≥ 3.10 con `pip`.
- `boto3`, `cryptography` (se instalan en el starter si usas el `requirements.txt`).
- **LocalStack** reachable en `AWS_ENDPOINT_URL` (default `http://localhost:4566`) con `kms`, `secretsmanager`, `ssm`.
- `jq` para validar JSON.

Si **LocalStack** no está disponible, el validador y los scripts hacen **SKIP** limpio para los pasos de red. Debes todavía producir los artifacts locales (key policy JSON, envelope artifact con el modo offline del script).

**Costos**: cero (LocalStack).

## 5. Instrucciones

### 5.1 Preparar scratch

```bash
mkdir -p /tmp/aws-09-store-fetch
cd /tmp/aws-09-store-fetch
```

### 5.2 Variables de entorno

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
```

### 5.3 Escribe `key-policy.json`

Copia la estructura del `examples/01-cmk-with-key-policy/key-policy.json` y adáptala al rol `arn:aws:iam::000000000000:role/checkout-task` (cuenta 000000000000 es la de LocalStack).

Debe contener los **4 Sids**: `EnableIAMDelegation`, `AllowKeyAdministration`, `AllowCheckoutAppDecrypt`, `AllowSecretsManagerUse`. El validador los comprueba.

### 5.4 Ejecuta `setup.sh`

Desde el repo:

```bash
bash <ruta-repo>/courses/aws/09-kms-secrets-manager-parameter-store/activities/01-store-and-fetch-secret-from-app/starter/setup.sh /tmp/aws-09-store-fetch
```

El script:

- Valida `jq` y `aws`.
- Si LocalStack no responde, crea `secret.json` y `param.json` con `status=SKIP` y continúa (modo offline).
- Si LocalStack responde:
  - Crea la CMK aplicando `key-policy.json`.
  - Crea el secret `fake/checkout/db` con payload JSON `{"username": "fake_app", "password": "fake-pw-NOT-REAL"}` cifrado con la CMK.
  - Crea el `SecureString` `/aws-09/fake/checkout/db/endpoint` con valor `fake.endpoint.localstack:5432` cifrado con la CMK.
  - Escribe `secret.json`, `param.json`, `cmk.json` en el scratch.

### 5.5 Ejecuta `envelope.py`

```bash
python3 <ruta-repo>/courses/aws/09-kms-secrets-manager-parameter-store/activities/01-store-and-fetch-secret-from-app/starter/envelope.py \
  --scratch /tmp/aws-09-store-fetch \
  --payload "fake-card-token-NOT-REAL-0001"
```

Modos:

- **Online** (LocalStack disponible + CMK creada): llama `kms:GenerateDataKey`, cifra con AES-GCM, escribe `envelope.json` con `wrapped_key_b64`, `nonce_b64`, `ciphertext_b64`, `tag_b64`, `cmk_id`, `payload_sha256`, `mode="online"`. Luego descifra y escribe `envelope.decrypted.txt`.
- **Offline** (LocalStack ausente): usa una data key sintética local (hash fijo), simula el blob y escribe `envelope.json` con `mode="offline"` + `warning="SKIP: KMS not reachable, local-only demo"`. Se mantiene la estructura del artifact para no romper el validador.

### 5.6 Ejecuta `app.py`

```bash
python3 <ruta-repo>/courses/aws/09-kms-secrets-manager-parameter-store/activities/01-store-and-fetch-secret-from-app/starter/app.py \
  --scratch /tmp/aws-09-store-fetch
```

El script simula el arranque de la app:

- Lee el `secret.json` y el `param.json` del scratch (los *outputs* del `setup.sh`).
- Si están en modo `online`, resuelve el valor real desde Secrets Manager y SSM.
- **Nunca** imprime el valor del secreto. Loguea `resolved secret OK (len=N)` y `resolved param OK (len=N)`.
- Escribe `app.log` con las entradas de inicio.

### 5.7 Entregables en `/tmp/aws-09-store-fetch`

```
/tmp/aws-09-store-fetch/
├── key-policy.json
├── cmk.json           # metadata de la CMK (o SKIP)
├── secret.json        # metadata del secret (o SKIP)
├── param.json         # metadata del parametro (o SKIP)
├── envelope.json      # artifact de envelope encryption
├── envelope.decrypted.txt  # payload resuelto (si modo online)
└── app.log
```

## 6. Resultado esperado

- `bash tests/validate.sh /tmp/aws-09-store-fetch` en verde.
- Los JSONs son `jq`-parseables.
- `key-policy.json` contiene los 4 Sids requeridos.
- `envelope.json` tiene todos los campos requeridos (incluso en modo offline).
- `app.log` no contiene cadenas que empiecen por `password=` o parecidas (el validador rechaza fugas).

## 7. Criterios de aceptación

- **Estructura**: validador en verde.
- **Correctness** (modo online): `envelope.decrypted.txt` ↔ payload de entrada.
- **No-leak**: en `app.log` no aparece el valor del secret ni del parameter.
- **Reproducibilidad**: `cleanup.sh` deja el scratch vacío.

## 8. Validación

```bash
bash <ruta-repo>/courses/aws/09-kms-secrets-manager-parameter-store/activities/01-store-and-fetch-secret-from-app/tests/validate.sh /tmp/aws-09-store-fetch
```

## 9. Preguntas de reflexión

1. ¿Por qué `envelope_decrypt` nunca necesita la CMK original explícitamente? ¿Qué le dice a KMS cuál CMK usar?
2. Si cambias la CMK (nueva key id) y re-cifras sólo las nuevas data keys, ¿puedes seguir descifrando payloads antiguos? ¿Por qué?
3. ¿Qué pasa si en la key policy olvidas `EnableIAMDelegation`? ¿Y si olvidas la condición `kms:ViaService` en el statement de Secrets Manager?
4. ¿Qué le pasaría a `app.py` si Secrets Manager devolviera `AWSPENDING` en vez de `AWSCURRENT`?
5. ¿Qué cambia en la práctica si pasas de `SecureString` a `String` sin cifrado para el endpoint de DB? (hay respuestas aceptables en ambas direcciones.)

## 10. Extensiones

- Añade un `EncryptionContext={"service": "checkout"}` tanto en `GenerateDataKey` como en `Decrypt`. Verifica que descifrar sin ese contexto falla.
- Rota la CMK (`EnableKeyRotation`) y comprueba que los `envelope.json` previos siguen descifrándose.
- Añade cache en memoria del secret durante 300 s en `app.py`.

## 11. Limpieza

```bash
bash <ruta-repo>/courses/aws/09-kms-secrets-manager-parameter-store/activities/01-store-and-fetch-secret-from-app/starter/cleanup.sh /tmp/aws-09-store-fetch
```

Borra el scratch, elimina el parámetro, elimina el secret y marca la CMK para destrucción (7 días en AWS real; stub en LocalStack).
