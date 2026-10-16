# helm-04-02 — Debug: fix broken indent & scoping

## 1. Identificación
- **ID:** `helm-04-02-fix-broken-indent`
- **Tecnología:** helm
- **Módulo:** 04-templating-deep
- **Dificultad:** intermediate
- **Duración estimada:** 45 min
- **Tipo:** debug (independent)

## 2. Contexto

Te dan un chart que **no renderiza**. Alguien (quizás tú, hace tres meses) escribió `_helpers.tpl` y un `deployment.yaml` que combinan tres errores clásicos del Helm templating. Tu trabajo es diagnosticar y arreglarlos leyendo el mensaje de `helm template --debug`, no la solución.

Los tres errores están entre los top-5 de bugs reales que verás en charts del mundo real. No se te dirá cuáles son.

## 3. Objetivos

- Diagnosticar errores de render leyendo el output de `helm template --debug`.
- Distinguir error de parse (sintaxis) vs error de ejecución (runtime).
- Aplicar las correcciones mínimas para que `helm template` pase.
- Explicar en una frase cada bug encontrado.

## 4. Prerrequisitos

- Helm 3+ instalado.
- Haber leído `theory/lesson.md` §6 (template vs include), §5 (scoping con `with`), §4 (nindent).
- Sin cluster: todo se valida con `helm template`.
- Sin costos.

## 5. Instrucciones

1. Copia el starter:
   ```bash
   cp -r starter /tmp/fix-broken-indent
   cd /tmp/fix-broken-indent
   ```
2. Intenta renderizar:
   ```bash
   helm template demo . --debug
   ```
3. Lee el error. El flag `--debug` imprime el YAML parcial renderizado — muy útil para localizar el bug.
4. Arregla UN bug a la vez. Vuelve a renderizar. Repite.
5. Cuando `helm template demo .` termine sin error, valida:
   ```bash
   bash <ruta-al-repo>/activities/02-fix-broken-indent/tests/validate.sh /tmp/fix-broken-indent
   ```

> Pista general (no es la solución): los bugs se concentran en `templates/_helpers.tpl` y `templates/deployment.yaml`. Mira con especial atención a los `include`/`template`, los `nindent`, y qué significa `.` dentro de un bloque `with`.

## 6. Resultado esperado

- `helm template demo .` renderiza sin error.
- El output contiene un `Deployment` con:
  - `metadata.labels` con 4 labels estándar (`chart`, `name`, `instance`, `managed-by`).
  - `spec.template.spec.containers[0].resources` indentado correctamente (requests y limits bajo resources).
  - `env` con dos variables (`APP_ENV`, `APP_RELEASE`) donde `APP_RELEASE` resuelve al nombre del release.
- El validador imprime `RESULT: 4/4 checks OK`.

## 7. Criterios de aceptación

- **Funcional.** `helm template demo .` tiene exit code 0.
- **Diagnóstico.** Puedes explicar qué bug había y por qué el mensaje de error apuntaba (o despistaba) hacia él.
- **Mínimo.** Las ediciones son locales; no re-escribiste el chart entero.
- **Reproducibilidad.** El validador pasa en dos ejecuciones consecutivas.

## 8. Validación

```bash
bash tests/validate.sh /tmp/fix-broken-indent
```

El script hace `helm template demo <dir>` y:

- Verifica exit code 0.
- Chequea que `resources:` del container tiene `requests:` y `limits:` como mapas (indentación correcta).
- Chequea que `APP_RELEASE` resuelve a `demo` (nombre del release).
- Chequea que las 4 labels estándar están presentes.

## 9. Preguntas de reflexión

- ¿Por qué el mensaje de error de `template "x" . | nindent 4` menciona "function not defined" aunque `template` sí existe? ¿Qué pista real da?
- ¿Qué pasa con `.` dentro de un bloque `{{- with .Values.image }}`? ¿Cómo accedes al root?
- ¿Por qué `toYaml | indent 4` falla pero `toYaml | nindent 4` no, en el mismo sitio?

## 10. Extensiones

- Ejecuta `helm lint` antes y después del fix. ¿`lint` detectó alguno de los bugs?
- Añade un segundo recurso (`Service`) que use el helper refactorizado y mantenlo correcto.
- Introduce un cuarto bug intencionadamente (p. ej. `required` sin mensaje) y verifica que el validador lo detecta.

## 11. Limpieza

```bash
rm -rf /tmp/fix-broken-indent
```
