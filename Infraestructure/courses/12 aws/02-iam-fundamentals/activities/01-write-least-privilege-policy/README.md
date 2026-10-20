# Actividad 01 — Reducir `"Action": "*"` a una política S3 de mínimo privilegio

## 1. Identificación

- **ID:** `aws-02-01-write-least-privilege-policy`
- **Tecnología:** `aws`
- **Módulo:** `aws-02-iam-fundamentals`
- **Dificultad:** beginner
- **Duración estimada:** 50–60 min
- **Tipo:** independent

## 2. Contexto

Un compañero te pasa esta policy, adjunta al rol `arn:aws:iam::123456789012:role/ReportsReader`, para "arreglar un AccessDenied que estaba bloqueando el deploy":

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "*",
    "Resource": "*"
  }]
}
```

Lo que la app **realmente** hace es: listar objetos bajo `s3://acme-reports/monthly/` y descargarlos. Nada más. Tu trabajo es sustituir esa policy por la mínima que cubra ese caso de uso y documentar las decisiones.

## 3. Objetivos

Al terminar deberías poder:

- Enumerar qué concede en realidad `"Action": "*"` + `"Resource": "*"` (no es "todo S3": es **todo AWS**).
- Escribir una policy S3 que permita **solo** `s3:ListBucket` acotado por prefijo + `s3:GetObject` sobre `monthly/*`.
- Separar los dos ARNs (bucket vs objeto) en dos statements con sus condiciones.
- Defender en prosa cada decisión (acciones incluidas, acciones excluidas, el `Condition` del prefijo, etc.).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` y el `examples/01-least-privilege-s3-readonly/`.
- `python3` (3.8+) para validar JSON.
- Opcional: `aws` CLI v2 con credenciales activas (SSO, access key, lo que sea) — el validador detecta si hay creds y, si no, salta la parte de `simulate-principal-policy`.

**Costos**: ninguno. `simulate-principal-policy` es gratis y no modifica nada.

## 5. Instrucciones

### 5.1 Prepara el scratch dir

```bash
mkdir -p /tmp/aws-02-lpp
cd /tmp/aws-02-lpp
```

Si usas otro path, pásalo al validador: `bash tests/validate.sh /otro/path`.

### 5.2 Escribe `POLICY.json`

Debe ser un documento IAM válido con:

- `Version`: `"2012-10-17"`.
- `Statement`: una lista con **al menos 2** statements.
- **Statement A**: `Effect: Allow`, acción `s3:ListBucket`, recurso `arn:aws:s3:::acme-reports`, con un `Condition` que acote por `s3:prefix` a `monthly/*` (y opcionalmente `monthly/`).
- **Statement B**: `Effect: Allow`, acción(es) `s3:GetObject` (y, si quieres, `s3:GetObjectVersion`), recurso `arn:aws:s3:::acme-reports/monthly/*`.
- **No** debe contener wildcards peligrosos: ni `"Action": "*"`, ni `"Resource": "*"`, ni `"Action": "s3:*"`.

Puedes copiar la policy del ejemplo `01-least-privilege-s3-readonly` como punto de partida; cópiala conscientemente, no mecánicamente.

### 5.3 Escribe `JUSTIFICATION.md`

Secciones mínimas:

1. **`## Qué concedía la original`** — explica *literalmente* qué permitía `"Action": "*"` + `"Resource": "*"`. Pista: incluye `iam:*`, `ec2:*`, `rds:*`. Mencionar explícitamente que incluye borrar la propia policy que la "contenía" es un buen detalle.
2. **`## Decisiones de la nueva policy`** — por cada statement, 2–4 líneas: qué acción incluyes, por qué, y por qué separaste bucket de objeto.
3. **`## Lo que deliberadamente dejé fuera`** — mencionar al menos 2 acciones *potenciales* que NO incluiste y por qué (p. ej. `s3:PutObject`, `s3:DeleteObject`, `s3:GetBucketLocation`, `s3:GetObjectAcl`).
4. **`## Cómo lo validaría contra el motor real`** — una frase mencionando `simulate-principal-policy` o el Policy Simulator y qué acciones esperas `allowed` vs `implicitDeny`.

### 5.4 Validar

```bash
bash <repo>/courses/aws/02-iam-fundamentals/activities/01-write-least-privilege-policy/tests/validate.sh /tmp/aws-02-lpp
```

El validador:

- Comprueba que `POLICY.json` existe y **parsea como JSON** con `python3 -c 'import json; json.load(open(...))'`.
- Verifica estructura (`Version`, `Statement` lista, cada statement con `Effect`, `Action`, `Resource`).
- Comprueba que **no** aparecen los wildcards peligrosos.
- Comprueba que `s3:ListBucket` y `s3:GetObject` sí aparecen.
- Comprueba que el bucket `acme-reports` aparece en los ARNs y que el prefijo `monthly` aparece.
- Comprueba `JUSTIFICATION.md` con sus 4 secciones.
- **Si** detecta credenciales AWS activas (variable de entorno `AWS_PROFILE` o `AWS_ACCESS_KEY_ID` set), opcionalmente intenta `aws iam simulate-custom-policy` pasando el `POLICY.json`. Si falla (no hay creds, no hay permiso), lo marca `SKIP` y no suma fallos.

### 5.5 Limpieza

```bash
rm -rf /tmp/aws-02-lpp
```

Nada más. No se ha creado ningún recurso en AWS.

## 6. Resultado esperado

- `POLICY.json` parsea como JSON y pasa los chequeos estructurales.
- `JUSTIFICATION.md` existe y tiene las 4 secciones.
- `validate.sh` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: policy JSON válida, mínima, con `Condition` por prefijo.
- **Calidad**: cada decisión está defendida en prosa (no basta con "lo necesito").
- **Reproducibilidad**: alguien ajeno al equipo puede leer `JUSTIFICATION.md` y reconstruir la lógica.
- **Mantenibilidad**: statements separados, Sids con nombre, sin wildcards innecesarios.

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-02-lpp
```

El validador NO revisa semántica fina. Para autoevaluación profunda compara con `solution/REFERENCE.md`.

## 9. Preguntas de reflexión

1. ¿Qué habría pasado si el bucket tuviera objetos cifrados con SSE-KMS *customer-managed*? ¿Qué permiso extra haría falta y *dónde* se declara?
2. Si la app pasara a necesitar también escribir reportes, ¿añadirías `s3:PutObject` al mismo statement B o crearías uno nuevo? ¿Por qué?
3. ¿Por qué `s3:ListBucket` no acepta como `Resource` el ARN del objeto (`acme-reports/*`) y sí el del bucket (`acme-reports`)?
4. Si en lugar de un rol la policy la adjuntases a un `IAM user`, ¿cambiaría algo en su contenido? ¿Y en su gestión?
5. ¿Qué firma dejaría en CloudTrail un intento de `s3:DeleteObject` con esta policy? ¿`AccessDenied`? ¿`accessDenied` con qué `errorCode`?

## 10. Extensiones

- Añade un tercer statement con `Effect: Deny` explícito sobre `s3:DeleteObject` para toda la cuenta. ¿Por qué podría ser una buena idea aunque la policy ya no lo permita?
- Reescribe la policy usando una **variable de policy** (`${aws:PrincipalTag/team}`) para que el prefijo dependa del tag del principal, no esté hardcodeado.
- Añade un `Condition` que exija `aws:SecureTransport = true` (TLS). Explica qué ataque mitiga.

## 11. Limpieza

```bash
rm -rf /tmp/aws-02-lpp
```
