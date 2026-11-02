# Actividad 02 — Scavenger hunt de manpages

## 1. Identificación

- **ID:** `sys-02-02-manpage-scavenger-hunt`
- **Módulo:** `sys-02-shell-command-anatomy`
- **Dificultad:** intermediate
- **Duración estimada:** 45 min
- **Tipo:** challenge

## 2. Contexto

Un buen operador no "sabe" los flags de todo — sabe **encontrar** los flags en 30 segundos. Este reto son 10 preguntas sobre 10 manpages reales. Nada de Google: sólo `man`, `info`, `whatis`, `apropos`, `tldr`, `--help`.

## 3. Objetivos

- Elegir la sección correcta de `man` cuando el nombre vive en varias.
- Navegar un manpage con `/pat`, `n`, `N`, `g`, `G`, `q` sin perder tiempo.
- Reconocer que lo que buscas puede estar en `OPTIONS`, `ENVIRONMENT`, `EXIT STATUS` o `FILES`.
- Extraer la respuesta exacta (flag, código, nombre literal) sin ejecutar los comandos.

## 4. Prerrequisitos

- `man`, `man-db`, `whatis`, `apropos` funcionales. `sudo mandb` si acabas de instalar.
- `man-pages`, `manpages-dev`, `openssh-client`, `systemd`, `rsync`, `curl`, `tar`, `grep`, `coreutils`, `findutils` instalados. En Alpine añade `man-pages`.
- (opcional) `tldr`.

## 5. Instrucciones

### 5.1 Copia el starter

```bash
cd /tmp
rm -rf manpage-hunt
mkdir manpage-hunt && cd manpage-hunt
cp <ruta-de-la-actividad>/starter/questions.md .
```

### 5.2 Resuelve

Lee `questions.md`. Para cada pregunta:

1. Decide qué manpage y qué sección necesitas (si dudas, `whatis <nombre>`).
2. Abre con `man <sec> <nombre>` y navega con `/pat`.
3. Extrae la respuesta exacta.

### 5.3 Entrega: `answers.md`

Crea `answers.md` en el mismo directorio con 10 bloques, uno por pregunta, en el formato:

```markdown
## P1
- comando usado: man 5 fstab
- respuesta: 5
```

### 5.4 Validar

```bash
bash <ruta-de-la-actividad>/tests/validate.sh /tmp/manpage-hunt
```

El validador comprueba estructura **y** la respuesta exacta de cada pregunta (son hechos verificables, no de opinión).

## 6. Resultado esperado

- `/tmp/manpage-hunt/answers.md` con 10 bloques `## Pn` y la respuesta correcta.
- `tests/validate.sh` sale con código 0.

## 7. Criterios de aceptación

- [ ] 10 bloques `## P1` … `## P10` presentes.
- [ ] Cada bloque incluye la línea `- comando usado:` con `man` o equivalente.
- [ ] Cada bloque incluye la línea `- respuesta:` con el valor exacto esperado.

## 8. Validación

```bash
bash tests/validate.sh /tmp/manpage-hunt
```

Automatizada: compara literalmente las respuestas contra la clave en `tests/`.

## 9. Preguntas de reflexión

- ¿Qué página fue la que más tardaste en localizar? ¿Por qué?
- ¿Qué página era más larga? ¿Cómo acotaste la búsqueda?
- ¿Alguna respuesta no estaba en `OPTIONS` sino en `ENVIRONMENT`/`EXIT STATUS`/`FILES`? ¿Cuáles?

## 10. Extensiones (opcional)

- **E1** — Convierte `answers.md` en una ficha personal con *cómo* localizaste cada respuesta (keybind usada, patrón buscado). Es una guía de "cómo busco en manpages" para tu yo del futuro.
- **E2** — Diseña **5** preguntas propias en el mismo formato para un compañero. Debe poder validarse automáticamente.

## 11. Limpieza

```bash
rm -rf /tmp/manpage-hunt
```
