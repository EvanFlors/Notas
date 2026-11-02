# Actividad 02 — Rollback de un upgrade que rompe

- **Tipo:** debug
- **Duración estimada:** 45 min
- **Entorno:** **VM o contenedor Rocky 9 / Alma 9 / Fedora 41+ desechable** (no tu máquina principal).

## Escenario

Estás de guardia. Hace diez minutos un compañero aplicó `dnf upgrade` en un servidor y ahora un paquete que te importa está en una versión que rompe el servicio. Necesitas **volver atrás la transacción exacta** sin tocar nada más.

El objetivo pedagógico es que ejecutes el ciclo completo: localizar la transacción culpable en `dnf history`, inspeccionarla, decidir si `undo` es viable, aplicarlo, y validar que el sistema volvió al estado anterior.

## Qué vas a conseguir

- Reproducir la condición "bad upgrade" en una VM: instalas un paquete en una versión, lo pinneas, lo despinneas, lo subes.
- Usar `dnf history` + `dnf history info` para identificar la transacción.
- Ejecutar `dnf history undo <id>`.
- Confirmar que el paquete volvió a la versión anterior.
- Documentar la limitación: qué habría pasado si el repo ya no tuviera la versión vieja.

## Por qué importa

En producción, la primera pregunta tras un incidente post-upgrade es "¿cómo volvemos atrás?". Si no sabes operar `dnf history undo` o no has entendido sus límites, pierdes minutos (u horas) críticos.

## Prerrequisitos

- Módulo `sys-04` completado.
- VM o contenedor Rocky Linux 9, Alma 9, o Fedora 41+ con `sudo` y acceso a repos oficiales.
  - Contenedor rápido: `docker run --rm -it rockylinux:9 bash` (luego `dnf install -y sudo` dentro).
- Comandos: `dnf`, `rpm`, `awk`.

## Instrucciones

Lee `starter/scenario.md`. El escenario es autocontenido: lo reproduces tú mismo con un paquete inocuo (`zsh`), simulas el "bad upgrade" y lo revierte.

## Validación

```bash
bash tests/validate.sh
```

Valida:

- Existe en `dnf history` una transacción de tipo `Undo` reciente.
- El paquete `zsh` **no** está instalado en la máquina al final (porque el `undo` revirtió también la instalación inicial — ver escenario).
- Hay registro en el log de dnf del `undo`.

## Entregables

- Captura o copia-pega de la salida de `dnf history` antes y después del `undo`.
- Explicación en una línea de **una** condición concreta en la que `dnf history undo` fallaría, y qué harías entonces.

## Solución de referencia

En `solution/rollback.sh`. Léela después de intentarlo.
