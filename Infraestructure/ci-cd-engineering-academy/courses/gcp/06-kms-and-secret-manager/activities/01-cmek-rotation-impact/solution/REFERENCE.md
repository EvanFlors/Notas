# Autoevaluación — gcp-06-01

Compara tu entrega con los archivos de este directorio.

## Puntos semánticos clave

1. **`rotation_period`** debe estar en formato `<segundos>s`. 90 días son `7776000s`. Si pusiste `"90d"` el apply fallaría.
2. **`version_template.algorithm`** debe ser exactamente `GOOGLE_SYMMETRIC_ENCRYPTION` para una CryptoKey `ENCRYPT_DECRYPT`. Otros valores (p. ej. `RSA_...`) son para `ASYMMETRIC_SIGN` / `ASYMMETRIC_DECRYPT`.
3. El **binding va sobre la CryptoKey** (`google_kms_crypto_key_iam_member`), no sobre el keyring ni sobre el project. Darlo a nivel project es sobre-privilegio.
4. **El `depends_on` del bucket sobre el binding** es imprescindible en la primera `apply`. No es cosmético.
5. **El demo debe pasar los `assert`.** Si no, es que la rotación de KEK está "re-cifrando" (bug conceptual): la DEK debe ser la misma antes y después de rotar.
6. **No reemplaces `000000000000`** por un project number real en los commits. Si lo haces, borras la privacidad del project y abres la puerta a ataques de enumeración.

## Variantes aceptables

- Nombres de recursos distintos (`kr-foo` en vez de `kr-data`): sintácticamente da igual.
- `rotation_period` entre 30d y 365d: todos válidos; justifica en el README.
- Usar `multi-region = EU` en el bucket requeriría una clave regional en `europe-west1` compatible — fuera de scope aquí.

## Variantes NO aceptables

- `--set-env-vars` para pasar un secreto en vez de `--set-secrets` (ver actividad 02).
- `roles/owner` o `roles/editor` en vez de `cryptoKeyEncrypterDecrypter`.
- Borrar `prevent_destroy` sin justificación: deja la clave vulnerable a `terraform destroy`.
- Commitear valores de secretos reales en cualquier archivo.
