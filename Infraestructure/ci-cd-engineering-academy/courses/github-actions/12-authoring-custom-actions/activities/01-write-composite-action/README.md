# Actividad 01 — Escribir una composite action

## 1. Identificación

- **ID:** `gha-12-01-write-composite-action`
- **Tecnología:** `github-actions`
- **Módulo:** `gha-12-authoring-custom-actions`
- **Dificultad:** intermediate
- **Duración estimada:** 45–60 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a construir una **composite action** que recibe un string y verifica que cumpla un **formato de versión semver** (`MAJOR.MINOR.PATCH`). Devuelve:

- `is-valid`: `"true"` o `"false"`.
- `major`, `minor`, `patch`: componentes individuales (si es válida).
- `normalized`: `"vMAJOR.MINOR.PATCH"` (prefijado con `v`).

Si el input es inválido y `inputs.fail-on-invalid` es `true`, la action falla el step.

Es un ejemplo prototípico de composite útil: lógica pura de shell, cero dependencias, se expande en el job que la llame.

## 3. Objetivos

Al terminar:
- Escribes un `action.yml` con `runs.using: composite` desde cero.
- Declaras `inputs` con `default` y `required`.
- Expones `outputs` propagando `steps.<id>.outputs.<n>`.
- Validas el `action.yml` estática y dinámicamente (simulando al runner).

## 4. Prerrequisitos

- `gha-04` y `gha-08` completadas.
- Bash, `python3` (con PyYAML para parsear la metadata).
- No requiere Node ni Docker.

**Costos**: ninguno (local).

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/composite-action-lab
cd /tmp/composite-action-lab/semver-check
ls
# verás un action.yml con PLACEHOLDERs que tienes que completar
```

El starter crea `/tmp/composite-action-lab/semver-check/action.yml` con la estructura básica y marcadores que debes rellenar.

### 5.2 Diseñar

Tu `action.yml` debe tener:

**Metadata**

- `name: "Semver check"`
- `description: "Validates a semantic version string (MAJOR.MINOR.PATCH)"`
- `author: "<tu nombre>"` (cualquier string)
- `branding.icon: "check-circle"` y `branding.color: "green"`

**Inputs**

| name              | required | default | descripción                            |
|-------------------|----------|---------|----------------------------------------|
| `version`         | true     | —       | string a validar                       |
| `fail-on-invalid` | false    | `false` | si `true`, fail el step cuando inválido|

**Outputs**

| name         | descripción                                                   |
|--------------|---------------------------------------------------------------|
| `is-valid`   | `"true"` o `"false"`                                          |
| `major`      | parte MAJOR (vacío si inválido)                               |
| `minor`      | parte MINOR (vacío si inválido)                               |
| `patch`      | parte PATCH (vacío si inválido)                               |
| `normalized` | `"vMAJOR.MINOR.PATCH"` si válido, vacío si no                 |

**Runs**

- `runs.using: composite`
- Un único step con `id: check`, `shell: bash`, un `env:` para pasar los inputs **sin interpolar** `${{ inputs.* }}` dentro del `run:`, y un `run:` que:
  1. Lee `VERSION` y `FAIL` del entorno.
  2. Comprueba con la regex `^[0-9]+\.[0-9]+\.[0-9]+$`.
  3. Emite todos los outputs vía `>> "$GITHUB_OUTPUT"`.
  4. Si inválido y `FAIL=true`, `exit 1` con un mensaje.

### 5.3 Pistas

Para separar `MAJOR.MINOR.PATCH` en Bash:

```bash
IFS='.' read -r MA MI PA <<< "$VERSION"
```

Para emitir outputs en composite, dentro del step hay que usar la env var del runner:

```bash
echo "is-valid=true" >> "$GITHUB_OUTPUT"
```

Y en `outputs:` de `action.yml`:

```yaml
outputs:
  is-valid:
    description: "true or false"
    value: ${{ steps.check.outputs.is-valid }}
```

### 5.4 Validar

```bash
bash tests/validate.sh /tmp/composite-action-lab
```

El validator:

1. Parsea `action.yml` con PyYAML y verifica la estructura (claves obligatorias, tipo correcto, outputs apuntan a `steps.check.outputs.*`).
2. Simula al runner: para 3 inputs (`1.2.3`, `v1.2.3` **inválido**, `abc` **inválido**), ejecuta el step y comprueba los outputs en `$GITHUB_OUTPUT`.
3. Comprueba el behavior de `fail-on-invalid=true` con una versión inválida (debe salir con status != 0).

### 5.5 Si te atascas

Mira `solution/action.yml` **después** de intentarlo. Puedes correr `bash solution/solve.sh /tmp/composite-action-lab` para generar la solución de referencia y comparar.

## 6. Resultado esperado

- `/tmp/composite-action-lab/semver-check/action.yml` válido.
- `tests/validate.sh` pasa con `OK` en todos los chequeos.

## 7. Criterios de aceptación

- [ ] `action.yml` parsea como YAML válido.
- [ ] `runs.using == "composite"` y tiene al menos un step con `id: check`.
- [ ] Declara los 2 inputs y los 5 outputs con sus `description`.
- [ ] Para `version=1.2.3`: `is-valid=true`, `normalized=v1.2.3`, componentes correctos.
- [ ] Para `version=v1.2.3`: `is-valid=false`, componentes vacíos (porque la `v` no cumple la regex).
- [ ] Para `version=abc` con `fail-on-invalid=true`: el step sale con status != 0.
- [ ] Dentro del `run:` **no** hay `${{ inputs.* }}` literalmente — se pasan por `env:`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/composite-action-lab
```

## 9. Preguntas de reflexión

1. ¿Por qué pasamos los inputs vía `env:` en lugar de interpolarlos directamente en el `run:`? ¿Qué cambia si `inputs.version` viniera de `github.event.issue.title`?
2. ¿Qué pasa si olvidas `id: check` pero sí referencias `steps.check.outputs.*` en `outputs:`? Pruébalo.
3. Si quisieras aceptar también `vMAJOR.MINOR.PATCH` como válido (con `v` opcional), ¿cómo cambia tu regex y tu `normalized`?
4. ¿Por qué una composite action no puede usar `@actions/core`? ¿Qué tendrías que hacer para usar el toolkit? (Pista: ya no sería composite.)
5. Para el consumidor: ¿cómo invocaría tu action con `fail-on-invalid=true` desde un workflow? Escribe el YAML del step.

## 10. Extensiones (opcional)

- **E1** — Añade un input `prefix` (default `"v"`) y respeta el prefijo elegido en `normalized`.
- **E2** — Añade soporte para pre-release (`1.2.3-rc.1`) y expón un output `pre-release`.
- **E3** — Escribe un workflow `.github/workflows/test.yml` que use `uses: ./` para testearla en PRs (no es ejecutable aquí, pero sí el YAML).

## 11. Limpieza

```bash
rm -rf /tmp/composite-action-lab
```
