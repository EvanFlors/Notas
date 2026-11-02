# Ejemplo 02 — Patrones de process substitution

Dos usos canónicos de `<(cmd)` y `>(cmd)`:

1. **Comparar dos salidas sin tocar disco**: `diff <(cmd1) <(cmd2)`.
2. **Hacer tee a múltiples sinks procesadores**: `tee >(gzip > a.gz) >(sha256sum > a.sha)`.

## Ejecución

```bash
cd files
bash demo.sh
```

## Qué deberías ver

- El `diff` reporta las diferencias entre los dos listados **sin crear ningún temporal**.
- Al final se generan `payload.gz` y `payload.sha` **en el mismo paso** desde una única fuente, sin pasar por un archivo intermedio.
- `ls /tmp` antes y después muestra que no quedó basura.

## Observa

- La sintaxis `>(cmd)` requiere `/dev/fd/N`; funciona en Linux moderno y macOS. En entornos muy restrictivos (algunos jails) puede fallar.
- `$?` tras `diff <(a) <(b)` es el exit code de `diff`, **no** de `a` ni `b`. Si necesitas capturar los status de los productores, usa `wait` sobre PIDs o convierte a pipeline con `${PIPESTATUS[@]}`.
