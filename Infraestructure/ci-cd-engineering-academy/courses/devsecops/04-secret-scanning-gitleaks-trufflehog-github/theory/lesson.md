# Lección — Secret scanning en el pipeline

## 1. Por qué es un problema recurrente

Un secreto filtrado en Git es **irrecuperable**. Aunque borres el archivo en el siguiente commit, el objeto blob queda en la base de datos del repo, accesible por hash, por reflog y por cualquier clon anterior. Una vez publicado, el secreto se asume **comprometido**: ha estado al alcance de scrapers automáticos (hay cientos escaneando `push events` de GitHub en segundos).

La conclusión operativa es brutal: **limpiar la historia nunca sustituye a rotar el secreto**. Rotar es irreversible; limpiar la historia solo reduce la exposición futura.

## 2. Dos capas, no una

### 2.1 Pre-commit (local, prevención)

Se ejecuta en la máquina del desarrollador **antes** de que el commit exista. Barato (milisegundos), feedback inmediato. La herramienta canónica es `pre-commit` (el framework de Python) con el hook de `gitleaks` o `trufflehog`.

Ventaja: el secreto no llega jamás a `.git/`. Limitación: el desarrollador puede desactivar el hook (`git commit --no-verify`), o puede no haberlo instalado. Es **necesario pero no suficiente**.

### 2.2 CI full-history scan (red de seguridad, detección)

Se ejecuta en el servidor, sobre **toda la historia** del repo, en cada PR y en `main`. En GitHub Actions esto requiere `fetch-depth: 0` en `actions/checkout` — por defecto el checkout es shallow (profundidad 1) y no vería commits viejos.

El scan de historia es el que te protege de:
- Un desarrollador que corrió `--no-verify`.
- Un repo que existía antes de que instalaras el hook.
- Un secreto en un merge commit que el pre-commit no interceptó.

### 2.3 GitHub secret scanning (plataforma, defensa en profundidad)

GitHub escanea automáticamente los repos **públicos** (gratis) y los privados con **GHAS** (Advanced Security, pago). Dos modos:

- **Detección**: alertas en Security tab, con partner alerts (los proveedores — AWS, Stripe, OpenAI — reciben notificación y pueden revocar el token automáticamente).
- **Push protection**: GitHub **bloquea el push** si detecta un patrón conocido. Es el único control que existe entre `git push` y la publicación efectiva. Para repos públicos ya es gratis.

Las tres capas son **complementarias**: pre-commit evita el 95 % de los casos, CI atrapa el 4 %, GitHub la fracción residual.

## 3. gitleaks: cómo funciona

`gitleaks` es una CLI escrita en Go. Dos subcomandos clave:

- `gitleaks detect` — escanea la **historia** del repo (git log) buscando secretos. Usar en CI.
- `gitleaks protect` — escanea los cambios **staged** (lo que vas a commitear). Usar en pre-commit.

El motor combina:

- **Reglas regex** por proveedor (`stripe`, `aws`, `github-pat`, `slack-webhook`, ...). ~160 reglas built-in.
- **Entropía Shannon** sobre strings largos — detecta blobs aleatorios aunque no coincidan con una regla.
- **Allowlist** declarativa en `.gitleaks.toml` (archivo, path, regex, stop-word).

Ejemplo mínimo de `.gitleaks.toml`:

```toml
title = "proyecto X — gitleaks config"

[extend]
useDefault = true

[allowlist]
description = "Permitir fixtures con fakes evidentes"
paths = [
  '''tests/fixtures/.*''',
]
regexes = [
  '''sk_fake_[A-Za-z0-9]+''',
]
```

**Regla de oro de los allowlist**: cada entrada debe tener justificación en el PR y, si es por tiempo (ej. "pendiente de rotación"), fecha de expiración documentada.

## 4. trufflehog: cuándo preferirlo

`trufflehog` tiene una capacidad que `gitleaks` no tiene de serie: **verifica** los secretos encontrados haciendo una llamada al proveedor (ej. un `GET` autenticado al API de Stripe). Esto reduce drásticamente los falsos positivos — un hallazgo "verified" es un secreto **real y activo**.

El coste es que trufflehog hace red egress, lo cual puede ser inaceptable en CI aislados. Patrón habitual: **gitleaks en pre-commit y PR** (rápido, sin red), **trufflehog en el pipeline de main** (lento, pero con verificación).

## 5. BFG y git filter-repo: la cirugía

Si un secreto llegó a `main`, hay que:

1. **Rotar** el secreto (invalidarlo en el proveedor) — **antes** de tocar la historia.
2. Comunicar al equipo y, si procede, a seguridad / clientes.
3. Reescribir la historia con `git filter-repo --replace-text` o `BFG --replace-text`, borrando el valor del blob en todos los commits que lo contienen.
4. **Force-push** la rama (riesgoso: coordinar; todo el equipo debe re-clonar).
5. Pedir a GitHub que invalide las cachés de los commits reescritos (hoy esto se hace vía soporte o reclonando el repo).
6. Post-mortem: por qué el pre-commit no funcionó, qué controles faltaban.

**`git filter-repo` es el reemplazo oficial de `git filter-branch`** (que fue deprecado). BFG sigue siendo útil por su velocidad para repos grandes.

Lo que **no** funciona:
- `git rm archivo && git commit` → el blob sigue accesible por hash.
- `--amend` sobre el último commit → solo arregla el último, no los anteriores.
- Borrar el repo y volverlo a crear → sí funciona para GitHub, pero pierdes toda la historia (y los clones ajenos siguen teniéndola).

## 6. Falsos positivos y disciplina de excepciones

Los FP típicos:

- **Fixtures de test** con claves obviamente falsas (`sk_test_...`, `ghp_FAKE...`).
- **Documentación** que ilustra un formato (`AKIA` + 16 chars de ejemplo).
- **Secretos de desarrollo local** (minikube certs, keys generadas por un `make dev`).
- **Hashes y UUIDs** con alta entropía que gatillan la heurística Shannon.

Dos tácticas limpias:

1. **Hacer los fakes obviamente fakes**: `sk_fake_do_not_use`, `ghp_FAKEabc0000`. gitleaks tiene stopwords configurables (`example`, `test`, `fake`, `dummy`) que puedes aumentar.
2. **Allowlist por path** antes que allowlist por regex. "Permito todo lo que esté en `tests/fixtures/`" es más auditable que "permito cualquier string que empiece por `sk_`".

Lo que no debes hacer: suprimir con `# gitleaks:allow` en el código sin razón; cada supresión necesita comentario (`# gitleaks:allow fixture-stripe-test-key, rotated 2026-01-15`).

## 7. Runbook canónico: rotar → notificar → limpiar

Cuando el scanner **real** avisa de un secreto filtrado:

| Paso | Acción | Por qué en este orden |
|------|--------|----------------------|
| 0 | Confirmar que el hallazgo no es FP (verificar en el proveedor si es posible) | No gastes el stop-the-line en una fixture |
| 1 | **Rotar** el secreto en el proveedor | Hace irrelevante la exposición futura |
| 2 | Revocar sesiones / tokens derivados si procede | Un API key puede haber generado JWTs |
| 3 | Notificar a seguridad y, si hay posible abuso, al equipo de incident response | Transparencia > reputación local |
| 4 | Buscar en logs del proveedor evidencia de uso no autorizado | Hora del commit → hora de rotación |
| 5 | Reescribir la historia con `git filter-repo --replace-text` | Reduce exposición de futuros clones |
| 6 | Force-push + comunicar re-clone al equipo | Sin esto, los clones viejos reintroducen el commit |
| 7 | Post-mortem: por qué entró, qué control falló, qué añadir | Prevenir el próximo |

Nunca invertir 1 ↔ 5. Rotar primero.

## 8. Resumen operativo

- Pre-commit en **toda** máquina de desarrollador — barato, inmediato.
- CI con `fetch-depth: 0` escaneando historia — red de seguridad.
- GitHub secret scanning + push protection — defensa de plataforma.
- `.gitleaks.toml` disciplinado: fakes evidentes + allowlist por path + comentario en cada excepción.
- Runbook grabado en piedra: **rotar primero, limpiar segundo**.
