# Actividad 02 — Instalador basado en `dialog` con fallback a `select`

**Tipo:** mini-project · **Duración:** 60 min · **Prereq:** actividad 01 completada.

## Objetivo

Construir un instalador simulado para una app ficticia que:

1. Pregunta al operador el **directorio destino** (default `/opt/demo-app`).
2. Pregunta qué **componentes** instalar entre `core`, `cli`, `docs`, `examples` (checklist; `core` siempre marcado por defecto).
3. Pide **confirmación** antes de proceder (default **no**).
4. Simula la instalación con una **barra de progreso** (`--gauge` de `dialog`/`whiptail`, o barra ASCII en modo fallback).
5. Es **dual-mode**: con flags no pregunta nada.
6. Detecta ausencia de `dialog`/`whiptail` y **cae a un modo `select`** sin fallar.
7. Detecta ausencia de TTY y falla con mensaje claro si faltan flags.

## Flags soportados (modo no-interactivo)

```
--target DIR            Directorio destino (default: /opt/demo-app).
--components a,b,c      Lista separada por comas: core,cli,docs,examples.
--yes                   Asume confirmación afirmativa.
--non-interactive       Fuerza modo flags-only; falla si falta un dato.
--force-fallback        Ignora dialog/whiptail aunque estén presentes
                        (para probar la rama select).
-h, --help              Imprime ayuda.
```

## Flujo esperado

1. Parsea flags.
2. Decide backend: `dialog` → `whiptail` → `select` (según `command -v` y `--force-fallback`).
3. Si falta `--target` y hay TTY, pregunta.
4. Si falta `--components` y hay TTY, pregunta (checklist).
5. Si no se pasó `--yes` y hay TTY, pide confirmación `y/N`.
6. "Instala" (simulado) imprimiendo pasos y, si hay backend TUI, un gauge.
7. Al final imprime una línea `INSTALLED target=/<dir> components=<a,b,c>` que el test busca.

## Pasos

1. Lee `starter/installer.sh` y los `TODO` marcados.
2. Implementa parseo de flags, detección de backend, prompts por backend y la "instalación" simulada.
3. Prueba manualmente con y sin `dialog`/`whiptail`.
4. Valida:

   ```bash
   bash tests/validate.sh starter/installer.sh
   bash tests/validate.sh solution/installer.sh
   ```

## Pistas

- Para checklist en `dialog`: `dialog --stdout --checklist "Componentes:" 15 50 4 core "Core" ON cli "CLI" OFF docs "Docs" OFF examples "Examples" OFF`.
- Para `--gauge`: `( echo 10; sleep 0.2; echo 40; … echo 100 ) | dialog --gauge "Instalando..." 7 60 0`.
- En modo fallback, usa `select` para elegir componentes de uno en uno (hasta que elija "Terminar"), y un bucle `for` que imprime pasos como barra ASCII.
- Para confirmar `y/N` en texto: `read -r -n 1 -p "..." ans; echo; [[ "$ans" =~ ^[yY]$ ]]`.

## Validación

El test ejecuta el instalador en **modo no-interactivo** con combinaciones de flags y comprueba:

- Que `--non-interactive` sin `--target` ni `TTY` falla con exit code ≠ 0.
- Que `--target X --components core,cli --yes --non-interactive` termina con exit 0 e imprime `INSTALLED target=X components=core,cli`.
- Que `--force-fallback --target X --components core --yes --non-interactive` también funciona (prueba que la rama fallback no requiere `dialog`).
- Que `--help` imprime la cadena `Uso:` y exit 0.
