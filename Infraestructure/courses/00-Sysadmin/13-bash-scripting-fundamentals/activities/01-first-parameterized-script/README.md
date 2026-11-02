# Actividad 01 — Primer script parametrizado (`greet.sh`)

## 1. Identificacion

- **ID:** `sys-13-01-first-parameterized-script`
- **Tecnologia:** `00-Sysadmin`
- **Modulo:** `sys-13-bash-scripting-fundamentals`
- **Dificultad:** intermediate
- **Duracion estimada:** 45 min
- **Tipo:** guided-lab

## 2. Contexto

Convertir el comando mas trivial del mundo — `echo "Hola mundo"` — en un script Bash robusto que:

- Acepta un nombre por argumento (default: `mundo`).
- Acepta un saludo por segundo argumento (default: `Hola`).
- Exige una tercera "firma" obligatoria, aborta con mensaje si falta.
- Imprime con `printf` en lugar de `echo`.
- Pasa `shellcheck` sin warnings.

Suena pequeño. Es el patron que repetiras en cada script que escribas despues.

## 3. Objetivos

Al terminar deberias poder:

- Añadir shebang y modo estricto a un script.
- Darle permisos de ejecucion.
- Parametrizar con `${var:-default}` y `${var:?msg}`.
- Entrecomillar interpolaciones correctamente.
- Diagnosticar y arreglar warnings de `shellcheck`.

## 4. Prerrequisitos

- `sys-01-bash-cli-foundations` completado.
- `shellcheck` instalado (`apt install shellcheck`, `brew install shellcheck`, `pacman -S shellcheck`).
- Lectura previa de `theory/lesson.md` secciones 2, 4, 7, 9.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el entorno

```bash
cp starter/greet.sh /tmp/greet.sh
chmod +x /tmp/greet.sh
cd /tmp
```

Inspecciona el starter:

```bash
cat /tmp/greet.sh
```

Debe ser una sola linea: `echo "Hola mundo"`. Sin shebang. Sin nada mas.

### 5.2 Añadir shebang y modo estricto

Edita `/tmp/greet.sh` y añade al inicio:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

Ejecuta:

```bash
/tmp/greet.sh
# Hola mundo
```

### 5.3 Parametrizar el nombre con default

Reemplaza la linea `echo "Hola mundo"` por:

```bash
name="${1:-mundo}"
echo "Hola $name"
```

Prueba:

```bash
/tmp/greet.sh           # Hola mundo
/tmp/greet.sh Ana       # Hola Ana
/tmp/greet.sh "Ana Luz" # Hola Ana Luz   <- gracias a las comillas en "$name"
```

### 5.4 Parametrizar el saludo

Añade un segundo parametro con default `Hola`:

```bash
name="${1:-mundo}"
greeting="${2:-Hola}"
echo "$greeting $name"
```

Prueba:

```bash
/tmp/greet.sh Ana Buenos\ dias   # Buenos dias Ana
```

### 5.5 Añadir una firma obligatoria

El tercer parametro — una firma — debe ser **obligatorio**. Si no esta, el script aborta con mensaje claro:

```bash
name="${1:-mundo}"
greeting="${2:-Hola}"
signature="${3:?Uso: $0 [nombre] [saludo] <firma>}"
echo "$greeting $name"
echo "-- $signature"
```

Prueba:

```bash
/tmp/greet.sh                            # aborta — faltan parametros
/tmp/greet.sh Ana                        # aborta — falta firma
/tmp/greet.sh Ana Hola "Equipo SRE"      # OK
echo "exit: $?"                          # 0
```

### 5.6 Reemplazar `echo` por `printf`

`echo` es suficiente aqui, pero el habito de este modulo es `printf`:

```bash
name="${1:-mundo}"
greeting="${2:-Hola}"
signature="${3:?Uso: $0 [nombre] [saludo] <firma>}"

printf '%s %s\n' "$greeting" "$name"
printf -- '-- %s\n' "$signature"
```

El `--` evita que `printf` interprete el `--` del formato como fin de opciones.

### 5.7 Pasar `shellcheck`

```bash
shellcheck /tmp/greet.sh
```

Debe salir **sin output** (todo OK). Si hay warnings, leelos y corrige. Los mas comunes a esta altura:

- `SC2086` — "Double quote to prevent globbing" — faltan comillas en una variable.
- `SC2250` — preferir `${var}` sobre `$var`.
- `SC2317` — codigo inalcanzable.

### 5.8 Validar

```bash
bash tests/validate.sh /tmp/greet.sh
```

Debe terminar con `OK: actividad completada correctamente.`

## 6. Resultado esperado

- `/tmp/greet.sh` tiene shebang `#!/usr/bin/env bash` y `set -euo pipefail`.
- Es ejecutable (`chmod +x`).
- Acepta 0, 1, 2 o 3 argumentos; aborta claramente sin firma.
- Pasa `shellcheck` sin warnings.
- `tests/validate.sh` pasa.

## 7. Criterios de aceptacion

- [ ] Funcionalidad: comportamiento correcto en los cuatro casos (sin args, 1 arg, 2 args, 3 args).
- [ ] Robustez: nombres con espacios se tratan como un solo argumento (comillas correctas).
- [ ] Calidad: `shellcheck` limpio.
- [ ] Reproducibilidad: `tests/validate.sh` pasa.

## 8. Validacion

```bash
bash tests/validate.sh /tmp/greet.sh
```

Chequea: shebang, `set -euo pipefail`, permiso ejecutable, comportamiento con/sin firma, nombres con espacio, `shellcheck` clean.

## 9. Preguntas de reflexion

1. Si usaras `${3:=firma}` en vez de `${3:?...}`, ¿que pasaria cuando el usuario no pasa firma? ¿Es mejor o peor para este script?
2. ¿Por que `printf '%s\n' "$msg"` es mas seguro que `printf "$msg\n"` cuando `$msg` puede venir del usuario?
3. ¿Que mensaje imprime `set -u` si olvidas una variable? Pruebalo quitando el default de `name`.
4. Si cambias el shebang a `#!/bin/sh`, ¿el script sigue funcionando? ¿Que caracteristicas pierdes? (Pista: `pipefail` no es POSIX antiguo.)

## 10. Extensiones (opcional)

- **E1** — Añade una opcion `-u`/`--upper` que convierta el saludo a mayusculas (`${greeting^^}` en Bash 4+).
- **E2** — Haz que el script lea tambien de la variable de entorno `GREET_NAME` si no se pasa `$1`.
- **E3** — Añade un modo `--help` que imprima el uso y salga con 0.

## 11. Limpieza

```bash
rm /tmp/greet.sh
```
