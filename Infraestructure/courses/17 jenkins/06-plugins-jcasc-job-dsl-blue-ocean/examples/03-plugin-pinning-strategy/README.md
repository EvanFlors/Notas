# Ejemplo 03 — Estrategia de pinning de plugins

Objetivo: ver un `plugins.txt` real con versiones pinneadas y entender la rationale.

Este ejemplo **no se ejecuta**. Es material de lectura y análisis.

## Archivos

- `plugins.txt` — lista de plugins con `nombre:version` por línea.
- `RATIONALE.md` — por qué cada plugin está presente y por qué está en esa versión.

## Reglas aplicadas

1. **Toda línea lleva `:version` explícita.** Ninguna `plugin:latest`.
2. **Comentarios con `#`** permitidos — útiles para marcar grupos.
3. **Orden**: primero los core (`configuration-as-code`, `job-dsl`, `workflow-aggregator`), luego por dominio.
4. **Blue Ocean no está instalado por defecto**: se añade solo si el equipo lo pidió y lo usa activamente (ver §5 de `theory/lesson.md`).
5. **Plugins obsoletos / sin uso** se eliminan en vez de dejarlos "por si acaso".

## Cómo se aplica

En la imagen oficial de Jenkins:

```bash
jenkins-plugin-cli --plugin-file plugins.txt
```

Esto descarga los JAR a `/usr/share/jenkins/ref/plugins/` y los deja listos para que el controller los active al arrancar.

## Cadencia de actualización

- **Quincenal**: PR con bumps de plugins no críticos.
- **Out-of-band**: PR inmediato si hay advisory de seguridad para un plugin instalado.
- **Nunca**: upgrade silencioso en producción sin PR.
