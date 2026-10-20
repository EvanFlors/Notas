# Actividad 02 — Detectar y corregir script injection

## 1. Identificación

- **ID:** `gha-13-02-detect-script-injection`
- **Tecnología:** `github-actions`
- **Módulo:** `gha-13-security-hardening`
- **Dificultad:** intermediate
- **Duración estimada:** 30–50 min
- **Tipo:** guided-lab

## 2. Contexto

Las interpolaciones `${{ github.event.* }}` dentro de bloques `run:` son el vector número uno de ejecución de código arbitrario en workflows públicos. El atacante abre un PR o un issue con un título especialmente diseñado y GHA, al evaluar la expresión **antes** de pasar al shell, injerta el payload directamente en la línea de comando.

El fix es mecánico pero conceptualmente importante: pasar el valor por una **variable de entorno** (`env:` en el step) y referenciarlo con `"$VAR"` (con comillas dobles). La variable captura el valor como *dato*, no como *código*.

Este lab te da un workflow con **tres instancias** de la vulnerabilidad en distintas formas, y tu trabajo es reescribirlo para que ningún `run:` interpole datos controlables por el actor del evento.

## 3. Objetivos

- Identificar las interpolaciones peligrosas en el workflow starter.
- Reescribir cada ocurrencia con el patrón `env:` + `"$VAR"`.
- Validar que el scanner regex no encuentra más interpolaciones `${{ github.event... }}` dentro de `run:`.
- Explicar en una línea por qué el fix funciona.

## 4. Prerrequisitos

- `bash`, `python3` con `pyyaml` (`pip install pyyaml`).
- Lección `gha-13` secciones 2.4 y 9.8 leídas.

**Costos**: USD 0, 100% local.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/sec-scanning
cd /tmp/sec-scanning/project
```

Verás `.github/workflows/triage.yml` con un workflow de triage que:
- Dispara en `issues: opened` y `pull_request_target: opened`.
- Lee título/cuerpo/autor y lo mete en varios `run:` **de forma insegura**.

### 5.2 Tarea

Reescribe `/tmp/sec-scanning/project/.github/workflows/triage.yml` para que:

1. **Ninguna** interpolación `${{ github.event.* }}` ni `${{ github.actor }}` ni `${{ github.head_ref }}` aparezca dentro de un bloque `run:`.
2. Todos esos valores lleguen al script vía `env:` del step.
3. Dentro del script, cada valor se referencia como `"$NOMBRE_VAR"` (**con comillas dobles**).
4. El resto de la lógica (los `echo`, el `gh issue comment`) sigue haciendo exactamente lo mismo.

Opcionalmente, aprovecha para pinnear la action `actions/github-script` a SHA (está sin pin en el starter) y restringir `permissions:`.

### 5.3 Validar

```bash
bash tests/validate.sh /tmp/sec-scanning
```

Debe reportar `RESULT: ALL CHECKS PASS`.

### 5.4 Pistas

- Pista 1: para pasar el título a un `run:`, el patrón es:
  ```yaml
  - env:
      ISSUE_TITLE: ${{ github.event.issue.title }}
    run: echo "Title was: $ISSUE_TITLE"
  ```
- Pista 2: `${{ github.actor }}` también es peligroso en algunos triggers; trátalo igual.
- Pista 3: los *comentarios YAML* no cuentan: el validator ignora las líneas que empiezan por `#`.

## 6. Resultado esperado

- `triage.yml` sigue siendo YAML válido.
- Grep `grep -nE 'run:.*\$\{\{ *github' triage.yml` → sin resultados.
- Cada step que usa un valor del evento declara `env:`.
- Validator: `RESULT: ALL CHECKS PASS`.

## 7. Criterios de aceptación

- [ ] YAML válido (parsea con `yaml.safe_load`).
- [ ] Cero interpolaciones `${{ github.event.* }}`, `${{ github.actor }}`, `${{ github.head_ref }}` dentro de `run:`.
- [ ] Cada valor dinámico se pasa por `env:` en el step correspondiente.
- [ ] Cada uso de la env var está entre comillas dobles (`"$VAR"`, no `$VAR` desnudo).

## 8. Validación

```bash
bash tests/validate.sh /tmp/sec-scanning
```

El validator:

1. Parsea el YAML con `yaml.safe_load`.
2. Recorre cada step de cada job y, si tiene `run:`, aplica un regex que busca interpolaciones peligrosas dentro del texto del script.
3. Si encuentra alguna → FAIL con la línea culpable.
4. Verifica que cada step que originalmente usaba un valor del evento ahora declara `env:` con al menos una variable mapeada a `${{ github.event... }}` o similares.
5. Verifica (grep) que la env var se usa con comillas dobles en el script.

## 9. Preguntas de reflexión

1. ¿Por qué `env:` + `"$VAR"` corta el vector si el valor del título del PR era `a"; rm -rf / #`? Describe la secuencia de evaluación.
2. ¿`$VAR` sin comillas dobles seguiría siendo seguro contra RCE? ¿Qué otras clases de problemas aparecen (word splitting, glob expansion)?
3. ¿Qué otros triggers / contextos tienen input controlable por el atacante? (lista al menos 4 campos distintos de los que has usado).
4. ¿Qué pasa si el workflow lee el valor desde `${{ steps.previous.outputs.something }}` donde `something` fue capturado de un evento inseguro? ¿Se "lava" el riesgo?

## 10. Extensiones

- **E1** — Añade un workflow adicional (`.github/workflows/comment-triage.yml`) que use `on: issue_comment` y procese el `comment.body` también de forma segura. Pínnealo a SHA.
- **E2** — Añade un step que use `actions/github-script@<SHA>` para hacer la misma operación en JS; muestra cómo el mismo valor se usa de forma segura ahí (`core.getInput`, no interpolación en template string).
- **E3** — Instala `zizmor` localmente (`pipx install zizmor`) y pásalo sobre el workflow. Compara su output con tu análisis.

## 11. Limpieza

```bash
rm -rf /tmp/sec-scanning
```
