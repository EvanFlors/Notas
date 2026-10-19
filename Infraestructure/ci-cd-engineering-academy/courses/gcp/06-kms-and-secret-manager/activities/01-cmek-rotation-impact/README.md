# Actividad 01 — CMEK, rotación e impacto (plan + demo local)

## 1. Identificación

- **ID:** `gcp-06-01-cmek-rotation-impact`
- **Tecnología:** `gcp`
- **Módulo:** `gcp-06-kms-and-secret-manager`
- **Dificultad:** intermediate
- **Duración estimada:** 70–80 min
- **Tipo:** independent (sin dependencia de la actividad 02)

## 2. Contexto

El equipo de Security te pide dejar documentada la **primera CMEK del project**: un keyring en `europe-west1`, una CryptoKey con rotación a 90 días y un bucket GCS protegido con esa clave. Además te pide un **demo local** que explique qué significa en la práctica "rotar la KEK" — porque la última vez que se hizo, un equipo creyó que al rotar la clave los datos quedarían automáticamente re-cifrados, y no es así.

No hay project GCP. **No se ejecuta `terraform apply`** y **no se habla con la API de KMS**. El entregable es:

- Un `main.tf` **plan-ready** (parseable; no se aplica).
- Un JSON con el IAM binding del service agent.
- Un `envelope-demo.py` **que corre localmente** con la librería `cryptography` y simula el modelo DEK/KEK incluyendo rotación.
- Un `README-IMPACT.md` explicando qué pasa al rotar y qué no.

**No uses project IDs ni valores de secretos reales.** Usa los placeholders del starter (`demo-cmek-example`, `000000000000`).

## 3. Objetivos

Al terminar deberías poder:

- Escribir un `main.tf` con `google_kms_key_ring`, `google_kms_crypto_key` (con `rotation_period` y `version_template`) y `google_storage_bucket` con `encryption.default_kms_key_name`.
- Escribir el IAM binding JSON (`cryptoKeyEncrypterDecrypter` sobre la CryptoKey para el service agent de GCS) con el formato `members`/`role`.
- Implementar un demo de envelope encryption con `cryptography.hazmat.primitives.ciphers.aead.AESGCM` (DEK) + `cryptography.hazmat.primitives.keywrap` (envoltura con KEK) y mostrar que rotar la KEK no re-cifra los payloads antiguos.
- Explicar por escrito el impacto operativo de la rotación.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§2, §3, §4).
- Haber revisado `../../examples/01-gcs-with-cmek/`.
- Herramientas locales: `bash`, `jq`, `python3` ≥ 3.9, paquete `cryptography` (`pip install cryptography`). **No se requiere** `terraform` CLI ni `gcloud`.

**Costos**: ninguno. Todo corre en tu máquina local.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gcp-06-cmek
cd /tmp/gcp-06-cmek
```

Puedes usar otro directorio; en ese caso pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `main.tf`

Nombres **exactos** de recursos (el validador los busca):

- `google_kms_key_ring` con nombre local `data` y `location = "europe-west1"`.
- `google_kms_crypto_key` con nombre local `bucket_key`, `purpose = "ENCRYPT_DECRYPT"`, `rotation_period = "7776000s"` y un `version_template` con `algorithm = "GOOGLE_SYMMETRIC_ENCRYPTION"` y `protection_level = "SOFTWARE"`.
- `google_kms_crypto_key_iam_member` que una la CryptoKey, el rol `roles/cloudkms.cryptoKeyEncrypterDecrypter` y un `member` `serviceAccount:service-...@gs-project-accounts.iam.gserviceaccount.com`.
- `google_storage_bucket` con `location = "europe-west1"`, `uniform_bucket_level_access = true` y bloque `encryption { default_kms_key_name = ... }`.

Usa variables `project_id`, `project_number` y `region` con los valores placeholder del starter (`demo-cmek-example`, `000000000000`, `europe-west1`). **No pongas IDs reales.**

### 5.3 Escribe `iam-binding-gcs-service-agent.json`

Un documento JSON con esta forma mínima (equivale al `getIamPolicy` de la CryptoKey):

```json
{
  "bindings": [
    {
      "role": "roles/cloudkms.cryptoKeyEncrypterDecrypter",
      "members": [
        "serviceAccount:service-000000000000@gs-project-accounts.iam.gserviceaccount.com"
      ]
    }
  ],
  "etag": "BwAAAA==",
  "version": 1
}
```

El validador comprueba que es JSON válido, que contiene exactamente ese `role`, al menos un `member` del tipo `serviceAccount:service-<numbers>@gs-project-accounts.iam.gserviceaccount.com`, y que el `version` sea un entero.

### 5.4 Escribe `envelope-demo.py`

Debe ser un script Python ejecutable (`python3 envelope-demo.py`) que:

1. Genere una **KEK v1** (32 bytes aleatorios).
2. Genere una **DEK** (32 bytes aleatorios).
3. Cifre un plaintext (p. ej. `b"customer-data-chunk-1"`) con la DEK usando AES-GCM (nonce de 12 bytes aleatorio).
4. **Envuelva** la DEK con la KEK v1 usando RFC 3394 (`cryptography.hazmat.primitives.keywrap.aes_key_wrap`).
5. Imprima en stdout algo como `WRAPPED_DEK_V1=<hex>` y `CIPHERTEXT=<hex>`.
6. **"Rote" la KEK**: genere una **KEK v2** nueva. Re-envuelva la DEK con la KEK v2 (`WRAPPED_DEK_V2=<hex>`).
7. Demuestre que:
   - Con la KEK v1 se puede *unwrap* `WRAPPED_DEK_V1` y descifrar el ciphertext original.
   - Con la KEK v2 se puede *unwrap* `WRAPPED_DEK_V2` y también descifrar el mismo ciphertext (porque la DEK es la misma; solo cambia su envoltura).
   - El **ciphertext no cambió**: rotar la KEK no re-cifra los datos.
8. Imprima al final la línea `ROTATION_IMPACT: ciphertext unchanged, both KEK versions decrypt`.

El validador ejecuta el script y comprueba que termina con `exit code 0` y que esa línea aparece en stdout.

### 5.5 Escribe `README-IMPACT.md`

Secciones obligatorias (el validador las busca por heading markdown):

- `## Decisiones de diseño` — justificar `rotation_period = 90d`, protection level `SOFTWARE`, `prevent_destroy`, `depends_on`.
- `## Impacto de la rotación` — explicar que rotar **no** re-cifra; qué pasa con objetos antiguos; cómo re-cifrar manualmente si fuera necesario (`gsutil rewrite -k`).
- `## Service agent` — explicar quién es `service-<project_number>@gs-project-accounts.iam.gserviceaccount.com`, por qué necesita el binding, qué error produce si falta.
- `## Costos` — orden de magnitud (menos de 1 USD/mes para esta configuración) y la **nota explícita** de que **no se ha aplicado nada**.

Debe mencionar explícitamente **KEK**, **DEK**, **envelope** y **CMEK** en el cuerpo. **No** llames al archivo `ANALYSIS.md` — usa `README-IMPACT.md`.

### 5.6 Entregables

```
/tmp/gcp-06-cmek/
├── main.tf
├── iam-binding-gcs-service-agent.json
├── envelope-demo.py
└── README-IMPACT.md
```

## 6. Resultado esperado

- Los 4 archivos existen.
- `main.tf` contiene los 4 recursos y los atributos obligatorios.
- `iam-binding-gcs-service-agent.json` parsea con `jq .` y cumple la estructura mínima.
- `python3 envelope-demo.py` corre sin error y emite la línea de impacto.
- `README-IMPACT.md` tiene las 4 secciones obligatorias y menciona KEK, DEK, envelope y CMEK.

## 7. Validación

```bash
bash tests/validate.sh /tmp/gcp-06-cmek
```

El validador comprueba estructura y ejecuta el demo. **No** se comprueba que el Terraform haga semánticamente lo que dice (eso requeriría `terraform plan` contra un project real). Compara con `solution/REFERENCE.md` para autoevaluación.

## 8. Criterios de aceptación

- **Funcionalidad**: validador pasa en verde.
- **Correctitud sintáctica**: HCL parseable (sin apostrofes mal cerrados), JSON válido, Python ejecutable.
- **Correctitud conceptual**: el demo demuestra que ciphertext no cambia tras rotar la KEK.
- **Mantenibilidad**: `main.tf` legible, variables con default, recursos nombrados consistentemente.

## 9. Preguntas de reflexión

1. Si bajas `rotation_period` de 90d a 7d, ¿qué pasa con el coste? ¿Y con el número de versiones activas al cabo de un año?
2. ¿Qué comando usarías para forzar el re-cifrado de un objeto concreto con la versión primary actual? ¿Y para todo el bucket?
3. Si borras la CryptoKey "por error" (asumiendo que no tiene `prevent_destroy`), ¿qué pasa con los objetos cifrados con ella? ¿Hay vuelta atrás?
4. ¿Por qué el binding va sobre la CryptoKey y no sobre el project? ¿Qué violaría si lo pusieras a nivel project?
5. ¿Qué cambia si el bucket es `multi-regional` (`EU`) y la clave es `europe-west1`? (Pista: no se puede.)

## 10. Extensiones

- Añade `google_kms_crypto_key_iam_member` adicional para `roles/cloudkms.cryptoKeyEncrypterDecrypterViaDelegation` sobre otra service account.
- Añade un segundo bucket que use `user-managed` replication y protección HSM; justifica el coste.
- Extiende el demo para rotar la KEK **tres veces** y mantener historial de envueltas (map `kek_version → wrapped_dek`).

## 11. Limpieza

```bash
rm -rf /tmp/gcp-06-cmek
```

No hay infraestructura que detener.
