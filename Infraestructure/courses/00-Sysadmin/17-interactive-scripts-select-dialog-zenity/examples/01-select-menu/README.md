# Ejemplo 01 — Menú con `select` puro

Un runbook minimalista para operar un servicio ficticio (`demo-app`) usando el builtin `select`. Sin dependencias externas: funciona en cualquier Bash 4+ y por SSH.

## Qué muestra

- `PS3` como prompt del menú.
- `$REPLY` (número) vs. `$opt` (string) dentro del `case`.
- Loop infinito que re-dibuja el menú tras cada acción, hasta que el usuario elige "Salir" y `break` rompe el loop.
- Validación de opción desconocida (`*`).
- Separación entre la lógica (`do_*`) y la UI del menú.

## Cómo ejecutarlo

```bash
bash files/demo.sh
```

Teclea 1, 2, 3 o 4. Pulsa Enter en vacío para re-pintar el menú.

## Observaciones

- `select` sigue mostrando el menú tras cada iteración; no hace falta reimprimirlo manualmente.
- Si `read` dentro de `select` recibe EOF (Ctrl-D), el loop termina igual que con `break`.
- Para menús con más de ~10 opciones, pasa a `dialog --menu`: la UX con `select` se degrada rápido.
