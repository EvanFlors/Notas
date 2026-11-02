# Ejemplo 01 — Quoting demo

## Concepto que demuestra

Cómo la elección entre **sin comillas**, **comillas simples** (`'...'`) y **comillas dobles** (`"..."`) cambia el resultado de un mismo comando, especialmente ante variables, globs y nombres con espacios.

## Contexto

El quoting es responsable de la mayoría de los bugs de shell en producción. Verlo ejecutándose es más efectivo que leer una tabla.

## Objetivo

Al terminar podrás responder:

- ¿Qué hace Bash cuando no entrecomillas una variable con espacios?
- ¿Por qué `'$HOME'` no se expande y `"$HOME"` sí?
- ¿Qué pasa con un `*` sin comillas si el CWD contiene archivos que matchean?

## Prerrequisitos

- Bash ≥ 4.
- Directorio escribible (usaremos `/tmp/`).

## Ejecución

```bash
cp files/demo.sh /tmp/quoting-demo.sh
chmod +x /tmp/quoting-demo.sh
/tmp/quoting-demo.sh
```

Lee el bloque de salida de cada sección antes de pasar a la siguiente.

## Resultado esperado

El script imprime seis bloques:

1. **Sin comillas**: una variable con espacios se divide en palabras.
2. **Simples**: la variable NO se expande.
3. **Dobles**: la variable SÍ se expande, SIN word splitting.
4. **Glob sin comillas**: Bash expande `*.sh` a la lista de archivos coincidentes.
5. **Glob entre comillas**: el `*` se preserva literal.
6. **Interpolación segura con `${}`**: concatenación sin ambigüedad.

## Interpretación

- Sin comillas: la shell aplica *word splitting* y *globbing* después de la expansión. Casi siempre no es lo que quieres.
- Simples: todo literal. Útil para patrones regex, mensajes exactos, código a transmitir (ej. `ssh host '...'`).
- Dobles: expande variables y `$(cmd)`, pero no divide ni globbing. **El default sensato.**

## Errores frecuentes

- **"Mi script falla cuando el usuario pasa un argumento con espacio"**: faltó entrecomillar `"$1"`.
- **"Mi mensaje se imprime raro con `$`"**: estás en comillas dobles cuando querías simples, o viceversa.
- **"El `rm *.log` eliminó cosas que no quería"**: el `*` se expandió en el CWD, no era literal.

## Relación con escenarios reales

- Scripts de deploy que fallan solo en servidores donde algún path contiene espacio.
- Scripts de backup que borran archivos equivocados por glob mal entrecomillado.
- Comandos remotos vía `ssh` que se expanden en el cliente en vez del servidor.

## Limpieza

```bash
rm /tmp/quoting-demo.sh
```
