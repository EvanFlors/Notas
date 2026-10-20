# obs-04-02-fix-empty-query — Diagnosticar queries PromQL vacías

## 1. Identificación

- **ID:** `obs-04-02-fix-empty-query`
- **Tecnología:** prometheus-grafana
- **Módulo:** 04-promql-fundamentals
- **Dificultad:** beginner
- **Duración estimada:** 45 min
- **Tipo:** debug (independiente)

## 2. Contexto

En soporte diario de observabilidad, el síntoma más común es: *"la query no muestra nada"*. En lugar de pedir ayuda, un ingeniero senior aplica un checklist mental y debuga en 2 minutos. Esta actividad entrena ese checklist contra 5 queries rotas sobre un fixture conocido.

## 3. Objetivos

- Diagnosticar la causa de cada query vacía.
- Diferenciar entre: nombre de métrica incorrecto, label incorrecto, ventana demasiado corta, función aplicada al tipo equivocado, falta `le` en `by`.
- Reescribir cada query para que devuelva ≥ 1 serie sobre el fixture.

## 4. Prerrequisitos

- Haber completado `obs-04-01-build-red-queries`.
- Software: `bash`, `grep`. Opcional: `promtool`.
- Costo: **cero**.

## 5. Instrucciones

**No se te da la solución**. En `starter/` encontrarás:

- `fixture.md` — el estado del `/metrics` del servicio (lo que *realmente* está expuesto).
- `broken-queries.promql` — 5 queries que devuelven vacío contra ese fixture.

Para cada query:

1. Lee la query y el fixture.
2. Formula una hipótesis sobre por qué está vacía (`# Hipótesis:` en el archivo).
3. Reescribe la query al lado (`# Fix:`).
4. Opcional: si tienes `promtool` o Prometheus en vivo, pruébalas.

Checklist mental sugerido:

1. ¿Existe la métrica con ese nombre exacto? Usa `{__name__=~"<prefijo>.*"}` para explorar.
2. ¿Los labels del selector coinciden con los expuestos?
3. ¿La ventana del range vector es ≥ 4 × scrape_interval?
4. ¿La función es válida para el tipo de métrica (counter/gauge/histogram)?
5. ¿`histogram_quantile` incluye `le` en el `by`?

## 6. Resultado esperado

`starter/broken-queries.promql` contiene, para cada query numerada:

- Una línea `# Hipótesis: ...` no vacía.
- Una línea `# Fix:` seguida por la query corregida.

## 7. Criterios de aceptación

- Las 5 hipótesis identifican correctamente la causa (una de las categorías del checklist).
- Las 5 queries "Fix:" devuelven ≥ 1 serie contra el fixture (verificable con `promtool query`).
- Las 5 queries "Fix:" pasan `promtool check rules` (sintaxis).

## 8. Validación

```bash
bash tests/validate.sh
```

El validador:
- Verifica que haya 5 bloques con `# Hipótesis:` y `# Fix:` no vacíos.
- Si `promtool` está disponible, valida la sintaxis de los Fix.
- SKIP para la ejecución en vivo salvo que exportes `PROM_URL`.

## 9. Preguntas de reflexión

1. ¿Qué cambio operativo mitigaría la query #3 (ventana corta) desde la configuración de Prometheus?
2. Por qué `rate()` sobre un gauge devuelve algo (no error de sintaxis) pero no tiene sentido físico?
3. ¿Cuándo preferirías `absent()` sobre `up == 0` para alertar?
4. ¿Qué linter o convención ayudaría a evitar olvidar `le` en `histogram_quantile`?

## 10. Extensiones

- Añade una 6ª query rota tuya y plántale el fix a un compañero.
- Convierte una de las queries corregidas en una recording rule.

## 11. Limpieza

El validador usa `/tmp/promql-02-*` y limpia al salir.
