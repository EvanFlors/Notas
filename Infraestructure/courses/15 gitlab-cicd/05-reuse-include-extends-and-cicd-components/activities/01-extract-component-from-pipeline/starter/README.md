# Starter — gl-05-01

Este directorio contiene el pipeline **duplicado** que vas a refactorizar. No modifiques nada aquí: copia los archivos a tu `/tmp/gl-05-01/` y trabaja allí.

## Archivos

- `duplicated-pipeline.gitlab-ci.yml` — un `.gitlab-ci.yml` de ejemplo que corre hoy en 7 proyectos del grupo, con variaciones mínimas por proyecto. Léelo entero antes de empezar.

## Cómo empezar

```bash
mkdir -p /tmp/gl-05-01/component/templates/node-test
mkdir -p /tmp/gl-05-01/consumer
cd /tmp/gl-05-01
# ahora crea component/README.md, component/templates/node-test/template.yml y consumer/.gitlab-ci.yml
```

Si prefieres otro directorio, pásalo al validador: `bash tests/validate.sh /tu/ruta`.

## Qué refactorizar

Lee `duplicated-pipeline.gitlab-ci.yml` y responde:

- **Qué es idéntico** entre proyectos → va al componente.
- **Qué varía poco** (versión de Node, flag de coverage, stage) → entra como `inputs:` del componente.
- **Qué es específico del proyecto** (deploy, variables de dominio, hooks) → se queda en el `consumer/.gitlab-ci.yml`.

Cuando termines, el pipeline consumer debe quedar en **menos de 25 líneas** y poder correr en los 7 proyectos cambiando solo los `inputs:`.
