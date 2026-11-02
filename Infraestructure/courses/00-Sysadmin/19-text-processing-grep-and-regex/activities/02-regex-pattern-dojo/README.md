# Actividad 02 — Dojo de patrones regex

## 1. Identificación

- **ID:** `sys-19-02-regex-pattern-dojo`
- **Tecnología:** `00-Sysadmin`
- **Módulo:** `sys-19-text-processing-grep-and-regex`
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** independent

## 2. Contexto

En la actividad anterior usaste regex "al vuelo" para contestar preguntas. Aquí el objetivo es distinto: **escribir regex correctas**. Las regex "mayormente correctas" son el bug más común del shell. Un patrón de email que acepta `foo@bar.` o un patrón de IPv4 que acepta `999.999.999.999` arruina validaciones aguas abajo.

El ejercicio es cerrado y auto-evaluable: para cada clase de string, hay un conjunto de **positivos** que debes aceptar y **negativos** que debes rechazar. El validador los corre contra tu regex con `grep -E` o `grep -P` según corresponda.

## 3. Objetivos

- Construir regex para 7 clases de string de uso diario.
- Elegir entre ERE y PCRE con criterio.
- Anclar con `^...$` cuando valides el string entero (no solo buscar en una línea).
- Diseñar un conjunto propio de negativos antes de dar por buena la regex.

## 4. Prerrequisitos

- Haber hecho `sys-19-01` (ya tienes `grep`/`awk` fluidos).
- `grep -E` disponible siempre; `grep -P` para los puzzles que lo marquen.

## 5. Instrucciones

### 5.1 Dataset

`starter/dataset.txt` contiene **todos** los positivos y negativos, prefijados por una etiqueta de clase y signo:

```
IPV4+ 192.168.0.1
IPV4+ 10.0.0.1
IPV4- 10.0.0.256
IPV4- 10.0.0
EMAIL+ ada@example.com
EMAIL- ada@
...
```

Formato: `<CLASE><+|-> <string>`.

### 5.2 Clases a resolver

Las 7 clases están en `starter/questions.md`:

1. **IPV4** — 4 octetos 0–255 separados por `.`. (ERE)
2. **EMAIL** — forma pragmática: `local@dominio.tld`. No pretendes RFC 5322. (ERE)
3. **ISODATE** — fecha ISO-8601 corta `YYYY-MM-DD`, años 1900–2099, meses 01–12, días 01–31 (no valida febrero 30; es puramente léxico). (ERE)
4. **UUID** — UUID v1–v5, hex con guiones, forma canónica. (ERE)
5. **BASHVAR** — nombre válido para variable bash: `[A-Za-z_][A-Za-z0-9_]*`. (ERE)
6. **URL** — URL `http(s)://host[:port][/path][?query]`. Pragmática, no RFC 3986. (ERE)
7. **HEXCOLOR** — color CSS tipo `#rgb` o `#rrggbb`, insensible a mayúsculas. (PCRE, por `(?i)`)

### 5.3 Entregable

Rellena `starter/patterns.sh`. Hay 7 variables declaradas:

```bash
REGEX_IPV4=''
REGEX_EMAIL=''
REGEX_ISODATE=''
REGEX_UUID=''
REGEX_BASHVAR=''
REGEX_URL=''
REGEX_HEXCOLOR=''
```

Y una variable `ENGINE_<CLASE>` para cada una, `E` (ERE) o `P` (PCRE), que indica cómo invocará el validador.

> Tu regex debe **anclar** con `^...$` para que el validador compruebe el string completo. Si no, cualquier patrón trivial `.` pasaría.

### 5.4 Validar

```bash
bash tests/validate.sh starter/patterns.sh
```

El validador, para cada clase:

1. Toma los positivos del dataset.
2. Toma los negativos.
3. Corre tu regex con el engine que indicaste.
4. Reporta cuántos positivos acepta y cuántos negativos rechaza.
5. Falla si no es **100 %** correcto en ambos lados.

## 6. Resultado esperado

- `tests/validate.sh` imprime `OK` para las 7 clases.
- El script `patterns.sh` pasa `shellcheck` (si está instalado).

## 7. Criterios de aceptación

- [ ] Las 7 regex están definidas y no vacías.
- [ ] Cada regex está anclada con `^...$`.
- [ ] 100 % de aciertos en positivos y negativos para las 7 clases.
- [ ] Para IPV4, tu regex rechaza octetos > 255 y strings con octetos vacíos.
- [ ] Para EMAIL, rechaza `foo@`, `@foo.com`, `foo@bar.` y `foo@@bar.com`.
- [ ] Para UUID, acepta mayúsculas y minúsculas en los hex pero exige los guiones.

## 8. Validación

```bash
bash tests/validate.sh starter/patterns.sh
```

## 9. Preguntas de reflexión

1. Para IPV4, ¿elegiste una alternancia explícita (`25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?`) o algo más corto? ¿Qué pasa si el input viene con ceros a la izquierda (`010.000.000.001`)?
2. Para EMAIL, enumera **tres** cosas que tu regex **no** valida y que una validación "de verdad" (ej. envío de magic-link) sí comprueba.
3. ¿Por qué HEXCOLOR es el único que exige PCRE en la lista? Reescribe la versión equivalente en ERE y comenta la diferencia.
4. Si quitas los anclajes `^$`, ¿cuál de las 7 regex es más peligrosa (acepta más cosas que no debería)?

## 10. Extensiones (opcional)

- **E1** — Añade una clase `IPV6` con suficientes positivos y negativos para validar la forma canónica + abreviada `::`.
- **E2** — Convierte el dataset en un fuzzer: genera 10 000 strings aleatorios y usa tu regex para clasificarlos. ¿Alguno te sorprende?

## 11. Limpieza

Ninguna.
