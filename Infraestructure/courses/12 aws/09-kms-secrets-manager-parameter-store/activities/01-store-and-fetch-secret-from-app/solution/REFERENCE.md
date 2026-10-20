# REFERENCE — aws-09-01-store-and-fetch-secret-from-app

> Referencia razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## 1. Key policy (modelo)

Idéntica a `starter/key-policy.template.json`. Puntos a defender:

- `EnableIAMDelegation` con `Principal.AWS = arn:aws:iam::000000000000:root` para que las IAM policies de la cuenta puedan autorizar operaciones.
- Statement de administración separado del de uso: higiene mínima aun en entornos de prácticas.
- Statement del rol `checkout-task` con `kms:Decrypt`, `GenerateDataKey*`, `DescribeKey`. No damos `kms:Encrypt` suelto porque las cifrados pasan por `GenerateDataKey*` (envelope).
- Statement de `secretsmanager.amazonaws.com` **con** `kms:ViaService=secretsmanager.us-east-1.amazonaws.com` y `kms:CallerAccount=000000000000`. Sin estas condiciones, la delegación al servicio es más amplia de lo necesario.

### Errores comunes

- Olvidar `EnableIAMDelegation` → AccessDenied aunque la IAM policy sea correcta.
- Poner `"Principal": { "AWS": "secretsmanager.amazonaws.com" }` (confundir servicio con rol) → inválido.
- Dar `kms:*` al rol de la app → viola least-privilege.

## 2. Envelope encryption (modelo)

Flujo correcto:

1. `kms:GenerateDataKey(KeyId=CMK, KeySpec="AES_256")` → `Plaintext` (32 bytes) + `CiphertextBlob` (wrapped).
2. Generar `nonce = os.urandom(12)` por payload (nunca reusar nonce con la misma key).
3. `AESGCM(Plaintext).encrypt(nonce, payload, aad=None)` → `ciphertext || tag`. Separar `tag` (últimos 16 bytes) para persistirlo aparte, lo que facilita integridad explícita.
4. `Plaintext` se sobre-escribe con ceros inmediatamente — Python no garantiza wipe, pero reduce la ventana.
5. Persistir `{wrapped_key_b64, nonce_b64, ciphertext_b64, tag_b64, cmk_id, payload_sha256}`.

Al descifrar:

- `kms:Decrypt(CiphertextBlob=wrapped)` → `Plaintext`. **No** se le dice a KMS cuál CMK: el blob lleva el `KeyId` dentro.
- `AESGCM(Plaintext).decrypt(nonce, ciphertext+tag, None)` → payload.

### Puntos a defender

- Por qué no cifrar directamente con `kms:Encrypt`: límite de 4 KB y 1 round-trip por byte si lo intentas segmentar — anti-patrón.
- Por qué `payload_sha256` en el blob: permite verificar integridad end-to-end después del descifrado sin tener que confiar sólo en el tag GCM.
- Por qué `EncryptionContext` es una buena extensión (actividad 10): atar el blob a un propósito.

## 3. App startup (modelo)

- Resolver `AWSCURRENT` por nombre, no por versión.
- Nunca loguear el valor; sólo `len=N` o un hash truncado.
- Fallar rápido en el arranque si el secret no resuelve: es preferible no arrancar a arrancar con credenciales vacías.
- En servicios de alto QPS, cachear el valor 300 s en memoria y recargar al recibir un `ClientError.InvalidSignatureException` (indicador típico de rotación).

## 4. Decisiones Secrets Manager vs Parameter Store (en este caso)

- **Password de DB** → Secrets Manager (ya que en producción habrá rotación integrada con RDS).
- **Endpoint de DB** → Parameter Store `SecureString`. No es realmente un secreto (DNS interno), pero cifrarlo mantiene consistencia operativa y evita que aparezca en logs de debug.
- **Card token fake** → envelope encryption local, almacenado como blob opaco; **no** va a Secrets Manager porque no es rotable y Secrets Manager cobra por secret.

## 5. Modo offline (cuándo y por qué)

- Mantener la actividad completable sin LocalStack reduce fricción y permite revisar el patrón conceptualmente.
- El `envelope.json` offline **no es seguro**: la data key es determinística. El propio artifact lo declara con `warning="SKIP: ..."`.
- El validador no distingue online/offline a nivel semántico: su trabajo es que el artifact exista con la forma esperada.

## 6. Limpieza

- `cleanup.sh` tolera errores (`set -u` sin `-e`) porque muchos recursos pueden no existir si el modo fue offline.
- La CMK en AWS real queda en `PendingDeletion` 7 días (configurable 7–30). En LocalStack el schedule es un stub.
