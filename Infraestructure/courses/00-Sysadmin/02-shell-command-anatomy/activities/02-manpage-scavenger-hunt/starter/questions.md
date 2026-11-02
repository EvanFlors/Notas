# Scavenger hunt — 10 preguntas, 10 manpages

Produce `answers.md` en el mismo directorio con una respuesta por pregunta en el formato:

```
## P<n>
- comando usado: man <sec> <nombre>
- respuesta: <texto corto exacto>
```

**Regla**: nada de Google. Sólo `man`, `info`, `whatis`, `apropos`, `tldr`, `--help`.

---

**P1.** ¿Qué **sección** de `man` tiene la página que describe el **formato** del archivo `/etc/fstab`? Da el número.

**P2.** En `grep`, ¿qué flag imprime sólo los **nombres de archivo** que contienen el patrón, sin las líneas que lo contienen? (Da la forma corta.)

**P3.** En `tar`, ¿qué opción **larga** cambia al directorio indicado antes de operar? (La corta equivalente es `-C`.)

**P4.** En `ls`, ¿qué variable de entorno controla la **ordenación** por locale (orden "natural")? Pista: aparece en la sección ENVIRONMENT.

**P5.** En `curl`, ¿cuál es el **exit code** cuando el servidor devuelve un HTTP ≥ 400 **y** se usó `-f`/`--fail`? Da el número.

**P6.** En `find`, ¿qué predicado selecciona archivos modificados **hace menos de 24 horas**? Da la forma exacta (incluye el signo si lo lleva).

**P7.** En `ssh_config` (sí, es un **formato de archivo**, no un comando), ¿qué opción fuerza una clave privada específica? Da el nombre literal.

**P8.** En `systemd.service` (otra página de formato), ¿qué directiva define el comando principal que systemd ejecutará para arrancar el servicio? Da el nombre literal.

**P9.** En `rsync`, ¿qué flag corto activa el modo **archive** (preserva permisos, enlaces, tiempos, recursivo)?

**P10.** En `signal` (sección 7), ¿cuál es el **número** de la señal `SIGKILL` en Linux x86_64? Da el entero.
