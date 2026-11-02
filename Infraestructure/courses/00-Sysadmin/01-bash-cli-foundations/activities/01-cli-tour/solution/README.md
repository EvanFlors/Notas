# Solución de referencia — `01-cli-tour`

> **No consultes este directorio hasta haber intentado la actividad.**

El script `build-workspace.sh` reproduce el estado esperado en `/tmp/cli-tour/`.
`append-bashrc.sh` muestra el fragmento sugerido para `~/.bashrc` (no lo aplica
automáticamente: es tu `.bashrc`, lo decides tú).

## Uso

```bash
./build-workspace.sh                 # construye /tmp/cli-tour
./append-bashrc.sh --preview         # imprime el fragmento sugerido
./append-bashrc.sh --apply           # lo añade a ~/.bashrc (haz backup antes)
```

## Decisiones y justificación

| Opción | Valor | Por qué |
|--------|-------|---------|
| `HISTSIZE` | 10000 | Suficiente para una semana larga de trabajo. |
| `HISTCONTROL` | `ignoredups:erasedups` | Historial limpio sin duplicados consecutivos ni repetidos. |
| `HISTTIMEFORMAT` | `'%F %T '` | Postmortems e incidentes se agradecen. |
| `shopt -s histappend` | on | Múltiples terminales no se pisan el historial al salir. |
| `rm -I` como alias de `rm` | sí | Protección anti-accidente sin ser tan ruidoso como `-i`. |
| `cp -i`, `mv -i` | sí | Pregunta antes de sobrescribir en modo interactivo. |
| `PS1` con `(exit=N)` | sí | Ves fallos inmediatamente sin teclear `echo $?`. |

## Respuestas a reflexión

**P1 (cd - vs popd).** `cd -` cambia a `$OLDPWD` (el *inmediatamente anterior*).
`popd` saca el tope de la pila `pushd`/`popd`, que puede tener múltiples niveles.
Si hiciste `pushd A; pushd B; pushd C`, `cd -` te lleva al cwd previo al último
cambio, mientras que `popd` te mueve a `B` (el anterior en la pila), `popd` otra
vez a `A`, etc.

**P2 (hardlink vs symlink al borrar el original).** El hardlink sigue funcionando
porque UNIX cuenta *referencias* al inodo (`nlink`): el archivo "se borra" solo
cuando `nlink` llega a 0 y nadie lo tiene abierto. El symlink queda roto
(*dangling*): es un archivo que contiene la ruta `notas.txt`, y esa ruta ya no
existe. `stat` del symlink sigue mostrando metadata; `cat` falla.

**P3 (ls -la vs ls -lA).** `-a` incluye `.` y `..`; `-A` incluye ocultos pero
*excluye* `.` y `..`. Para scripts y revisiones, `-A` es casi siempre lo que
quieres.

**P4 (HISTCONTROL=ignorespace).** Toda línea que empieza con un espacio no se
guarda en el historial. Útil para teclear comandos con tokens secretos
(`[espacio]export API_KEY=xxx`) o pruebas que no quieres recordar.

**P5 (source vs ejecutar).** `source ~/.bashrc` (o `. ~/.bashrc`) evalúa el
archivo en la **shell actual** — las variables, aliases y funciones aplican a tu
sesión. `bash ~/.bashrc` lanza un **proceso hijo** nuevo que evalúa el archivo
y muere; nada persiste en tu shell. Las modificaciones a `PATH`, `PS1`, aliases,
etc. se evaporan.
