# Ejemplo 02 — `protected` × `masked`: la matriz completa

> Lectura y análisis. Clarifica qué significa realmente cada combinación de flags.

## Matriz 2×2

|  | `masked: false` | `masked: true` |
|---|---|---|
| **`protected: false`** | Variable "abierta". Legible desde cualquier branch. Visible en logs. Útil para URLs, nombres de bucket, flags sin valor sensible. | Variable legible desde cualquier branch pero filtrada en logs. Útil para tokens de dev/stg que no son super sensibles pero no quieres que se peguen en pantalla. |
| **`protected: true`** | Variable legible solo desde refs protegidas; **visible en los logs** (sin enmascarar). Útil para ARNs/URLs de prod que no son secretos pero sí sensibles al contexto. | **El caso canónico para secretos de prod**: solo accesible desde refs protegidas y además enmascarada en logs. |

## Qué `masked` **no** hace (importante)

Supongamos `MY_TOKEN=supersecret123` con `masked: true`. Un job que haga:

```yaml
script:
  - echo "$MY_TOKEN"              # imprime [masked]
  - echo "$MY_TOKEN" | base64     # imprime c3VwZXJzZWNyZXQxMjM=  (NO enmascarado)
  - echo "${MY_TOKEN:0:4}"        # imprime supe  (NO enmascarado)
  - printf '%s' "$MY_TOKEN" > /tmp/t && cat /tmp/t  # imprime supersecret123 — ¡fuga!
```

GitLab solo enmascara apariciones **literales** del string. Cualquier transformación (base64, substring, hash, truncado) pasa en claro.

**Regla**: no inventes transformaciones de secretos en el log. Si necesitas un hash para debug, calcula `sha256sum` del valor y publícalo *una vez* en Vault; nunca imprimas derivados.

## Requisitos que `masked: true` impone al valor

Si el valor no cumple, GitLab **rechaza** el flag `masked` (en versiones modernas) o lo acepta pero **no enmascara** (en versiones viejas). Requisitos:

- Longitud ≥ 8.
- Un solo renglón (sin `\n`).
- Alfabeto: `[A-Za-z0-9+/=@:._~-]`. Caracteres fuera del alfabeto (`!`, espacios, acentos) hacen el valor no enmascarable.
- Base64 "puro" sí es enmascarable (es el caso típico de JWTs y de keys ascii-armored *si* van en una sola línea).

Un **JSON de GCP service account** (multilinea, con `\n`) **no** es enmascarable como `variable` → usar `file`.

## Escenario de fuga típica (y cómo evitarla)

### Antes (fuga)

```yaml
deploy:
  variables:
    SLACK_WEBHOOK: "https://hooks.slack.com/services/T00/B00/XXX"   # ← inline en el YAML
  script:
    - curl -XPOST -d "{\"text\":\"deploy ok\"}" $SLACK_WEBHOOK
```

Problema: el webhook está en el `.gitlab-ci.yml` versionado. Cualquiera con read access al repo lo ve. No es "variable de CI", es texto plano.

### Después (correcto)

- Definir `SLACK_WEBHOOK` en Project → Settings → CI/CD → Variables con `protected: true` + `masked: true`.
- En el `.gitlab-ci.yml`:

```yaml
deploy:
  script:
    - 'curl -XPOST -d "{\"text\":\"deploy ok\"}" "$SLACK_WEBHOOK"'
```

Ahora el valor nunca está en el repo; solo en la configuración del CI/CD, protegido y enmascarado.

## Diagnóstico: "mi variable no se enmascara"

Checklist:

1. ¿El flag está realmente activado en la UI? (muchas veces se olvida).
2. ¿El valor cumple los requisitos de alfabeto/longitud?
3. ¿Estás imprimiendo el valor literal o una transformación (base64, substring)? Las transformaciones no se enmascaran.
4. ¿El job tiene `set -x` activo? Si es así, el *comando entero* se imprime; el enmascarado se aplica después, pero cualquier interpolación transformada escapa.

## Siguiente

Ejemplo `03-secrets-from-vault-with-idtoken`: el patrón moderno — en vez de meter el secreto como variable, pedírselo a Vault con un ID Token efímero.
