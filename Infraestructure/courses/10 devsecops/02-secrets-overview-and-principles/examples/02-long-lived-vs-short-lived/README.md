# Ejemplo 02 — Long-lived vs short-lived: la cuenta cuantitativa

> Lectura y análisis. Sin ejecución. Objetivo: ver con **números concretos** por qué eliminar long-lived es la ganancia individual más grande.

## 1. El modelo mental

Para **cualquier** secreto, definimos tres variables:

- `p_diaria` — probabilidad por día de que se filtre (log leak, laptop robada, insider, forgetful commit, dump de proceso, …).
- `TTL` — cuántos días vive el secreto.
- `impacto` — qué puede hacer alguien que lo tenga durante su ventana de validez.

Entonces:

```
riesgo ≈ (1 - (1 - p_diaria) ^ TTL) × impacto
```

El término `(1 - (1 - p_diaria)^TTL)` es la **probabilidad acumulada de fuga** antes de que caduque. Con `p_diaria` chica, se aproxima a `p_diaria × TTL`.

Si fijamos `p_diaria = 0.001` (una fuga cada mil días en promedio — pesimista razonable para una API key que pasa por laptops, CI, logs):

| TTL        | P(leak antes de caducar) |
|------------|--------------------------|
| **15 min** | ~0.00001 % |
| 1 hora     | ~0.00004 % |
| 1 día      | 0.1 %      |
| 7 días     | 0.7 %      |
| 30 días    | 3 %        |
| 90 días    | 8.6 %      |
| 1 año      | ~30 %      |
| 3 años     | ~66 %      |

Un token de 15 minutos tiene ~**4 millones de veces menos probabilidad** de ser filtrado antes de caducar que una PAT de 3 años.

## 2. Comparativa concreta: dos secretos, mismo objetivo

Objetivo: subir artefactos a un bucket S3 desde CI.

### 2.1 Opción A — AWS access key `long-lived` (anti-patrón clásico)

```
   GitHub Secret:  AWS_ACCESS_KEY_ID = AKIAFAKEABCDEFGHIJKL
                   AWS_SECRET_ACCESS_KEY = sk_fake_wJalrXUtnFEMI/K7MDENG/bPxRfiCY...

   IAM policy (vieja, "porque funciona"):
      Action: "s3:*"
      Resource: "*"

   TTL real:      2 años (nadie la rota)
   Ventana:       730 días
   Alcance:       todos los buckets de la cuenta
   Scope:         s3:* en * — leer, escribir, borrar, cambiar policies
```

**Blast radius si se filtra:**

- `read + write + delete` en **todos los buckets** → exfiltración masiva, ransomware por sobreescritura, destrucción de datos.
- `s3:PutBucketPolicy` → exfiltración abierta al mundo (public read) con un solo call.
- 730 días × `p_diaria = 0.001` → **~52 % de probabilidad** de haber fugado al menos una vez antes de rotarla.

### 2.2 Opción B — OIDC federation con token short-lived

```
   GitHub Actions workflow:
      permissions:
        id-token: write
        contents: read
      steps:
        - uses: aws-actions/configure-aws-credentials@v4
          with:
            role-to-assume: arn:aws:iam::123456789012:role/ci-artifact-uploader
            aws-region: us-east-1

   IAM role (narrow):
      Trust policy:   confia solo en token.actions.githubusercontent.com
                      sub = repo:ORG/REPO:ref:refs/heads/main
      Action:         s3:PutObject, s3:AbortMultipartUpload
      Resource:       arn:aws:s3:::ORG-artifacts/releases/*

   TTL del token:  15 min (max 12h con configuracion explicita)
   Ventana:        0.01 día (900 s)
   Alcance:        prefijo "releases/" de UN bucket
   Scope:          s3:PutObject + s3:AbortMultipartUpload — nada mas
```

**Blast radius si se filtra:**

- Sólo `PutObject` en `releases/` de **un** bucket, durante los próximos ~15 min.
- No puede leer, no puede borrar, no puede cambiar policies.
- 0.01 día × `p_diaria` → **~0.00001 %** de probabilidad de fuga antes de expirar.
- Incluso filtrado: el atacante tiene **minutos** para subir basura al prefijo `releases/`. Se detecta en el próximo deploy.

## 3. Lado a lado

| Dimensión | Opción A (long-lived) | Opción B (OIDC short-lived) |
|-----------|-----------------------|------------------------------|
| Secret estático | **Sí** (en GitHub Secrets) | **No** (ningún valor estático) |
| TTL | 730 días | 900 segundos |
| P(leak antes de caducar) con p=0.001/día | **~52 %** | ~0.00001 % |
| Scope IAM | `s3:*` en `*` | `s3:PutObject` en `arn:...:ORG-artifacts/releases/*` |
| Auditoría de uso | Débil (una sola identidad genérica) | Fuerte (cada token lleva el `sub` del workflow) |
| Rotación | Manual, ritualista, propensa a saltarse | **Automática por caducidad** |
| Esfuerzo de setup | 10 min | 2 h la primera vez (OIDC trust policy) |
| Coste de incidente | Catástrofe cloud-wide | Un prefijo de bucket, por minutos |

**La "ganancia individual más grande"** del módulo tiene una tabla concreta: la de arriba.

## 4. Patrón mental para auditar un secreto cualquiera

Pregúntate, en orden:

1. ¿Existe un mecanismo **short-lived** equivalente? (OIDC, STS, Workload Identity, Vault dynamic, keyless signing).
   - Si sí → migrar es la acción de mayor retorno.
2. Si no, ¿el **scope** del secreto se puede **estrechar**? (sacar `admin:*`, limitar a repos/paths específicos, quitar `delete`).
3. Si el scope ya es mínimo, ¿se puede **acortar el TTL** aunque sea manual? (de 2 años a 90 días, de 90 días a 30 días).
4. Si el TTL ya es corto, ¿la **detección** cubre uso anómalo? (anomalía por geografía, por volumen, por horario).

Los cuatro pasos atacan los cuatro factores de `riesgo = scope × ventana × probabilidad × detección`.

## 5. Puntos a repetir hasta que suenen aburridos

- **Un long-lived no es "un secret cómodo"; es "una contraseña que crece de valor cada día que vive".**
- **Short-lived no exige menos cuidado, exige otro cuidado**: trust policies estrechas, verificación de `sub`/`aud`, rotation de roles si expones un nuevo workflow con permisos mayores.
- **"Rotar cada 90 días" es un placebo** comparado con "no tener secret estático en absoluto". Prefiere lo segundo cuando puedas.
