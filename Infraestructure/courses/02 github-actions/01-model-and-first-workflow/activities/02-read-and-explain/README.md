# Actividad 02 — Leer un workflow ajeno y predecir qué ocurre

## 1. Identificación

- **ID:** `gha-01-02-read-and-explain`
- **Tecnología:** `github-actions`
- **Módulo:** `gha-01-model-and-first-workflow`
- **Dificultad:** beginner
- **Duración estimada:** 40–50 min
- **Tipo:** independent

## 2. Contexto

En un trabajo real, el primer contacto con pipelines de GHA será **leyendo** workflows que escribió otra persona. Esta actividad entrena ese músculo: te damos un workflow algo intencionadamente *imperfecto* y debes predecir qué hace, qué falla, y por qué.

Como es *independent*, el README **no te resuelve** el workflow — solo te da las preguntas. Debes contestar en un archivo `ANSWERS.md`. Un validador verifica que tus respuestas contengan la información correcta (por keywords y patrones, no por match literal).

## 3. Objetivos

Al terminar:

- Puedes leer un workflow desconocido token por token.
- Identificas triggers, jobs, orden, dependencia (`needs:`), uso de `uses:` vs `run:`.
- Detectas antipatterns comunes de principiante.
- Articulas por escrito el **por qué** de cada predicción.

## 4. Prerrequisitos

- Haber completado `gha-01-01-first-workflow`.
- Git ≥ 2.30, Python 3 ≥ 3.9, PyYAML.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash courses/github-actions/01-model-and-first-workflow/activities/02-read-and-explain/starter/bootstrap.sh /tmp/gha-01-read-and-explain
```

El bootstrap crea `/tmp/gha-01-read-and-explain/` con:

- `workflow-under-review.yml` — el workflow a leer. **No lo edites**; es la "entrada" del ejercicio.
- `ANSWERS.md` — archivo con el formulario a rellenar. **Edita este**.

### 5.2 Leer el workflow

Abre `workflow-under-review.yml`. Léelo **sin ejecutarlo**. Identifica:
- Qué triggers tiene.
- Cuántos jobs tiene y en qué orden corren.
- Qué steps hay en cada job y qué hace cada uno.
- Qué `uses:` descarga y cuál es su propósito.
- Dónde hay un olvido o un antipattern.

### 5.3 Responder

Abre `ANSWERS.md` y responde las **6 preguntas** siguientes. Cada respuesta debe estar bajo su heading (`## Q1`, `## Q2`, …) y debe contener al menos la información que el validador busca (ver sección *Validación* más abajo para qué keywords detecta).

**Q1 — Triggers.** ¿Qué eventos disparan este workflow y en qué ramas? Si pusheas a `main`, ¿cuántos workflow runs se crean? Si abres un PR contra `main`, ¿cuántos?

**Q2 — Orden de jobs.** Enumera los jobs y di cuáles corren en paralelo y cuáles secuencialmente. Si uno falla, ¿qué pasa con los demás?

**Q3 — Checkout.** El job `publish` no tiene `actions/checkout`. ¿Qué consecuencia tiene esto? ¿Es un bug o una decisión válida? Argumenta.

**Q4 — `uses:` vs `run:`.** Para cada step del job `build`, clasifícalo como `uses` o `run` y resume qué hace en una línea.

**Q5 — Variables de contexto.** El step "Report" imprime varias `$GITHUB_*`. ¿De dónde salen esos valores? ¿En qué momento se les asigna valor?

**Q6 — Re-run.** Si abres este run en la UI y haces click en "Re-run failed jobs", ¿qué YAML usa — el actual de `main` o el del commit disparador? ¿Y si cambiaste el YAML en `main` desde que corrió?

### 5.4 Validar

```bash
bash courses/github-actions/01-model-and-first-workflow/activities/02-read-and-explain/tests/validate.sh /tmp/gha-01-read-and-explain
```

El validador:
1. Verifica que `ANSWERS.md` existe y tiene los 6 headings `## Q1` … `## Q6`.
2. Para cada respuesta, chequea que mencione al menos *N* keywords/patrones correctos.
3. Verifica que `workflow-under-review.yml` no fue modificado (hash check).

## 6. Resultado esperado

- `ANSWERS.md` con las 6 respuestas, cada una con los conceptos clave esperados.
- `workflow-under-review.yml` intacto.
- `tests/validate.sh` termina con `OK`.

## 7. Criterios de aceptación

- [ ] 6 headings `## Q1` … `## Q6` presentes.
- [ ] Q1 menciona `push`, `pull_request`, y referencia a `main`.
- [ ] Q2 identifica `needs:` entre `publish` y `build` (publish depende de build).
- [ ] Q3 explica que publish NO tiene workspace poblado (sin checkout) y por qué eso es un bug para el caso dado.
- [ ] Q4 clasifica correctamente los 3 steps de `build`.
- [ ] Q5 menciona el *runner agent* y/o el *contexto github* o el *payload del evento*.
- [ ] Q6 menciona que re-run usa el YAML del *commit disparador* del run original.
- [ ] `workflow-under-review.yml` sin modificar.

## 8. Validación

```bash
bash courses/github-actions/01-model-and-first-workflow/activities/02-read-and-explain/tests/validate.sh /tmp/gha-01-read-and-explain
```

Lee `tests/validate.sh` para ver exactamente qué keywords busca cada pregunta.

## 9. Preguntas de reflexión

(Después de pasar el validador, piensa:)

1. ¿Qué fue lo más difícil de predecir — triggers, orden, o algo del contexto?
2. Si tuvieras que *arreglar* el workflow para que publish funcione, ¿qué cambiarías y por qué?
3. ¿Qué patrón del workflow dado reutilizarías en un workflow tuyo?

## 10. Extensiones (opcional)

- **E1** — Escribe una versión arreglada del workflow en `fixed.yml` y pásala por el validador de `gha-01-01-first-workflow` (reutilizable).
- **E2** — Instala `actionlint` y corre contra el workflow. ¿Qué detecta que tú no detectaste?
- **E3** — Pushea el workflow a un repo tuyo y confirma empíricamente tus predicciones.

## 11. Limpieza

```bash
rm -rf /tmp/gha-01-read-and-explain
```
