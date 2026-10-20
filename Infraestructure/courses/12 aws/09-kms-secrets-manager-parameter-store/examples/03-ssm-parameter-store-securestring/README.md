# Ejemplo 03 — SSM Parameter Store `SecureString` con CMK propia

> Ejecutable contra **LocalStack**. Objetivo: ver que `SecureString` **no es un tipo distinto de almacenamiento** — es un `String` que SSM pasa por `kms:Encrypt`/`kms:Decrypt` con la CMK que tú elijas.

## 1. Prerrequisitos

- LocalStack corriendo con `kms` y `ssm` habilitados (ver `resources/links.md`).
- `aws` CLI (o `awslocal`) y `jq` instalados.

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
```

Comprueba que están disponibles:

```bash
curl -s http://localhost:4566/_localstack/health | jq '.services | {kms, ssm}'
# {"kms": "available|running", "ssm": "available|running"}
```

Si no, salta este ejemplo (es demostrativo, no bloqueante). El script `demo.sh` también detecta esto y hace **SKIP** limpio.

## 2. Ejecutar el demo

```bash
bash examples/03-ssm-parameter-store-securestring/demo.sh
```

El script:

1. Crea una CMK (`aws kms create-key`) con `Description=aws-09-ex03-cmk`.
2. Guarda el `KeyId`.
3. Crea un parámetro `SecureString` en `/aws-09/example/db/password` cifrado con esa CMK, valor `fake-password-NOT-REAL`.
4. Lee el parámetro **sin** `WithDecryption` → devuelve el blob cifrado.
5. Lee el parámetro **con** `WithDecryption` → devuelve el texto plano.
6. Limpia el parámetro y marca la CMK para destrucción (schedule 7 días en AWS real; LocalStack lo acepta como stub).

## 3. Qué deberías observar

- El `Value` sin desencriptar aparece como texto base64 ilegible.
- Con `WithDecryption=True` aparece exactamente `fake-password-NOT-REAL`.
- Si borras la CMK antes de leer con `WithDecryption`, la lectura falla (en AWS real; LocalStack puede ser laxo aquí — es un stub).

## 4. Puntos a interiorizar

- **El tamaño del valor sigue limitado por el tier** (4 KB en standard). SSM cifra el valor en reposo, pero no cambia el límite.
- `SecureString` **no** es visible en texto plano por default en consola: hay que pedir explícitamente `WithDecryption=True` y tener `kms:Decrypt` en la CMK.
- Puedes mezclar en la misma jerarquía `String` y `SecureString`: `GetParametersByPath` los devuelve todos; los `SecureString` vendrán cifrados salvo que pases `WithDecryption=True` (y tengas el permiso).

## 5. Script

Ver `demo.sh`. El script lleva `set -eu`, no `pipefail` (por el patrón `... | jq`/`grep` que puede producir SIGPIPE 141 en pipelines con early-exit), y hace cleanup incondicional vía `trap`.
