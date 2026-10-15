# Ejemplo 01 — Hook nativo `pre-commit` en `.git/hooks/`

## Concepto que demuestra

El hook más básico: un script bash en `.git/hooks/pre-commit` que **bloquea el commit** si detecta un patrón prohibido (en este caso, `TODO` sin owner como `TODO(nombre):`). Demuestra el ciclo:

```
git commit → Git ejecuta .git/hooks/pre-commit → exit 0 permite / exit !=0 aborta
```

## Contexto

- Es el hook nativo *puro*: cero dependencias, puro bash.
- No se versiona por default (vive en `.git/hooks/`, no en `/tracked_files/`).
- Útil para entender el mecanismo antes de pasar al framework `pre-commit` en la actividad 01.

## Objetivo

Al terminar:
- Sabes dónde viven los hooks (`.git/hooks/`) y los `.sample` que trae `git init`.
- Entiendes que un hook es cualquier ejecutable con el nombre correcto.
- Observas cómo un `exit 1` **aborta** el commit.
- Observas que el hook corre aun con `git commit -m "..."` (sin editor).

## Prerrequisitos

- Git ≥ 2.30, bash.

## Ejecución

Ejecuta el script completo o reproduce manualmente:

```bash
bash files/run-example.sh
```

### Reproducción manual

```bash
rm -rf /tmp/hook-native && mkdir -p /tmp/hook-native && cd /tmp/hook-native
git init -q -b main
git config user.name "Demo" && git config user.email "demo@example.com"

# Ver los samples que trae git init
ls .git/hooks/
# → pre-commit.sample, commit-msg.sample, pre-push.sample, etc.

# Instalar nuestro hook
cat > .git/hooks/pre-commit <<'EOF'
#!/usr/bin/env bash
# Rechaza commits que añaden "TODO" sin owner.
# Owner válido: TODO(nombre): texto
set -e

files=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(py|sh|md|txt)$' || true)
if [ -z "$files" ]; then
  exit 0
fi

bad=""
for f in $files; do
  # TODOs sin "(owner)" después
  hits=$(grep -nE 'TODO([^(]|$)' "$f" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    bad+="--- $f ---"$'\n'"$hits"$'\n'
  fi
done

if [ -n "$bad" ]; then
  echo "ERROR: TODOs sin owner. Usa 'TODO(nombre): texto'." >&2
  echo "$bad" >&2
  exit 1
fi
EOF
chmod +x .git/hooks/pre-commit

# 1) Caso FAIL: TODO sin owner
cat > app.py <<'EOF'
def foo():
    # TODO: refactor this
    return 42
EOF
git add app.py
git commit -m "feat: add foo"
# → ABORTED por el hook

# 2) Caso OK: TODO con owner
cat > app.py <<'EOF'
def foo():
    # TODO(alice): refactor this
    return 42
EOF
git add app.py
git commit -m "feat: add foo"
# → commit creado
```

## Resultado esperado

- Primer `git commit` aborta con mensaje de error del hook.
- Segundo `git commit` pasa.
- `git log --oneline` muestra 1 commit.

## Interpretación

- **`.git/hooks/pre-commit`** es un path hard-coded; Git lo busca por nombre exacto.
- **`chmod +x`** es obligatorio; si no, Git lo ignora silenciosamente.
- El hook lee el **index** vía `git diff --cached` (no el working tree): valida lo que *se va a commitear*, no todo lo que está sucio.
- Un `set -e` + `exit N` es la forma canónica de abortar.
- Puedes bypasear con `git commit --no-verify`. Es intencional: el hook es ayuda, no barrera dura (eso es trabajo del server / CI).

## Limitaciones observadas (que motivan el framework)

- **El hook no viaja**. Si borras `/tmp/hook-native` y clonas el proyecto desde otro lado, el hook no está. Hay que re-instalarlo manualmente.
- **No hay versiones**. Si mejoras el hook, los demás no se enteran salvo coordinación.
- **Un script, un chequeo**. Añadir 5 chequeos distintos sin perder legibilidad es tedioso.

La actividad 01 muestra cómo el framework `pre-commit` resuelve estos tres puntos.

## Errores frecuentes

- Olvidar `chmod +x` → el hook "no hace nada".
- Shebang incorrecto (`#!/bin/sh` vs `#!/usr/bin/env bash`) → sintaxis bash no funciona.
- Usar `git diff` en lugar de `git diff --cached` → valida el working tree y no el commit que vas a crear.
- Pipes con `set -o pipefail` + `grep -q` pueden dar exit 141 por SIGPIPE si el productor sigue escribiendo tras el match. Evitar o estructurar sin pipefail.

## Relación con escenarios reales

- Repos pequeños y personales que quieren un chequeo trivial sin pagar el costo de instalar `pre-commit`.
- Hooks de servidor en remotos propios (`pre-receive`, `update`) donde el flujo es exactamente el mismo (script + exit code).

## Limpieza

```bash
rm -rf /tmp/hook-native
```
