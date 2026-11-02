# Ejemplo 01 — Prompt y readline

## Concepto que demuestra

Cómo se construye un `PS1` útil y cómo navegar por readline sin tocar el ratón. Resultado: un prompt informativo con usuario, host, cwd, exit code del último comando y rama Git (si aplica), más los atajos esenciales para editar la línea.

## Contexto

El prompt es tu interfaz principal con la máquina durante horas al día. Un prompt bien diseñado te ahorra errores (ves si estás en producción), te ahorra ciclos (ves el exit code sin teclear `echo $?`) y hace el log de una sesión reproducible.

## Objetivo

Al terminar podrás:
- Explicar cada escape de `PS1` (`\u`, `\h`, `\w`, `\$`, `\[`, `\]`).
- Instalar un prompt propio en `~/.bashrc`.
- Editar líneas largas con atajos readline sin flechas.
- Buscar en el historial con `Ctrl-R` y reutilizar argumentos con `!$` y `Alt-.`.

## Prerrequisitos

- Bash ≥ 4.
- Acceso a tu `~/.bashrc`.
- `git` opcional (para el segmento de rama).

## Ejecución

Reproduce estos bloques en una terminal. **Lee la salida antes de ejecutar el siguiente.**

```bash
# 1. Prompt actual
echo "PS1 actual: $PS1"

# 2. Prompt mínimo (prueba en vivo, no persiste)
PS1='[\u@\h \W]\$ '
# -> [evan@laptop foundations]$

# 3. Prompt con color + exit code
_prompt_status() {
  local ec=$?
  if [ $ec -ne 0 ]; then
    printf '\001\e[31m\002(exit=%d)\001\e[0m\002 ' "$ec"
  fi
}
PS1='\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\] $(_prompt_status)\$ '

# 4. Probar que el exit code aparece
false
# -> prompt dibuja (exit=1) en rojo

# 5. Historial útil
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
export HISTTIMEFORMAT='%F %T '
shopt -s histappend

# 6. Readline en acción: edita esta línea sin flechas
#    Teclea (sin Enter):   echo "cadena larga que quiero editar"
#    - Ctrl-A      -> inicio
#    - Ctrl-E      -> fin
#    - Alt-B / Alt-F -> por palabra
#    - Ctrl-W      -> borrar palabra atrás
#    - Ctrl-U      -> borrar hasta inicio
#    - Ctrl-K      -> borrar hasta fin
#    - Ctrl-R      -> busca en historial (teclea 'echo')

# 7. Reutilización de argumentos
ls /tmp
cd !$        # !$ -> último argumento del comando previo (/tmp)
cd -         # vuelve al anterior

# 8. Instalar permanente
#    Ver files/sample.bashrc.d
```

Para instalar la configuración mostrada, revisa `files/sample.bashrc.d` y añade:

```bash
# Al final de tu ~/.bashrc:
[ -r ~/.bashrc.d/01-prompt.sh ] && . ~/.bashrc.d/01-prompt.sh
[ -r ~/.bashrc.d/02-history.sh ] && . ~/.bashrc.d/02-history.sh
```

## Resultado esperado

- Prompt que muestra usuario, host, cwd y, cuando hay error, `(exit=N)` en rojo.
- `history` con timestamps.
- Edición de línea sin flechas con los atajos de readline.

## Interpretación

- **`\[` y `\]`** marcan secuencias no imprimibles. Sin ellas, readline cuenta los códigos ANSI como caracteres visibles y el wrap de líneas largas se rompe.
- **`$(_prompt_status)`** se re-evalúa en cada prompt porque está dentro de `PS1`; captura `$?` antes de que cualquier otro comando lo pisotee.
- **`HISTCONTROL=ignoredups:erasedups`** elimina duplicados consecutivos *y* elimina las viejas apariciones de una línea que repites. Combinado con `shopt -s histappend` evita que múltiples terminales se pisen el historial.

## Errores frecuentes

- **Prompt rompe el wrap de líneas largas** — olvidaste `\[` / `\]`.
- **El exit code siempre es 0** — moviste `_prompt_status` fuera de `PS1` y lo evalúas antes.
- **El historial se pierde entre terminales** — falta `shopt -s histappend` o cada shell escribe al salir pisando la anterior.
- **`Ctrl-S` congela la terminal** — flow control XON/XOFF. Recupera con `Ctrl-Q`. Desactivar: `stty -ixon`.

## Relación con escenarios reales

- Operador en producción con 10 terminales abiertas: un prompt que incluya `[prod]` o el hostname evita ejecutar comandos destructivos en la máquina equivocada.
- Debugging de un script con muchos pipes: ver `(exit=1)` inmediatamente ahorra teclear `echo $?`.
- Postmortem: `HISTTIMEFORMAT` + `history` reconstruye qué hiciste y cuándo.

## Limpieza

El prompt experimental de la sesión actual se pierde al cerrar la terminal. Lo que hayas copiado a `~/.bashrc.d/` queda — bórralo si no lo quieres.
