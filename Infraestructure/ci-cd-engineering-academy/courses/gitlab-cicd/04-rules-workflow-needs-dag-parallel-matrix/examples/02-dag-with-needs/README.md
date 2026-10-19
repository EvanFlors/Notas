# Ejemplo 02 — De pipeline lineal a DAG con `needs:`

> Lectura y análisis. Sin ejecución. Objetivo: ver el **mismo** pipeline en dos versiones y entender dónde desaparece el wall clock.

## 1. Versión lineal (sin `needs:`)

```yaml
stages: [build, test, deploy]

build-amd64:
  stage: build
  script: sleep 180 && echo "built amd64"   # 3 min

build-arm64:
  stage: build
  script: sleep 180 && echo "built arm64"   # 3 min

unit-tests:
  stage: test
  script: sleep 300 && echo "unit"          # 5 min

lint:
  stage: test
  script: sleep 60 && echo "lint"           # 1 min

integration:
  stage: test
  script: sleep 240 && echo "integration"   # 4 min

deploy-stg:
  stage: deploy
  script: sleep 120 && echo "deploy stg"    # 2 min
```

### Wall clock lineal

```
build (max=3m) ──▶ test (max=5m) ──▶ deploy (max=2m)   TOTAL = 10 min
```

`lint` termina en 1 min pero bloquea el stage. `deploy-stg` no empieza hasta que `unit`, `lint` **e** `integration` terminen todos.

## 2. Versión DAG (con `needs:`)

```yaml
stages: [build, test, deploy]

build-amd64:
  stage: build
  script: sleep 180

build-arm64:
  stage: build
  script: sleep 180

unit-tests:
  stage: test
  needs: ["build-amd64"]
  script: sleep 300

lint:
  stage: test
  needs: []                           # arranca ya, no espera a build
  script: sleep 60

integration:
  stage: test
  needs: ["build-amd64", "build-arm64"]
  script: sleep 240

deploy-stg:
  stage: deploy
  needs: ["unit-tests"]               # NO espera a integration ni a lint
  script: sleep 120
```

### Wall clock DAG

Camino crítico: `build-amd64` (3m) → `unit-tests` (5m) → `deploy-stg` (2m) = **10 min**.

Pero el otro camino, `integration` (3m build + 4m test = 7m), termina **en paralelo** y no bloquea el deploy porque `deploy-stg` sólo depende de `unit-tests`. `lint` termina en 1 min y ya no bloquea nada.

**Mejora**: si `deploy-stg` tuviese que esperar a todo el stage `test` (versión lineal), serían `3 + 5 + 2 = 10 min` pero con `integration` extendiéndose a 4 min pasarías a 12 cuando el runner de `unit` fuese más lento. Con el DAG, el deploy sale en cuanto `unit` acaba.

En pipelines reales con 20+ jobs, la ganancia típica es **20–40%** del wall clock.

## 3. Visualización en GitLab

En la UI del pipeline, pestaña **"Needs"** o **"DAG view"**, GitLab dibuja el grafo. Cada flecha es un `needs:`. Los jobs sin flecha de entrada son los nodos iniciales (`needs: []` o sin dependencias en el primer stage).

## 4. Checklist antes de meter `needs:` en producción

- [ ] ¿El pipeline tiene >5 jobs? Si no, probablemente no vale la pena.
- [ ] ¿Los `needs:` reflejan dependencias **reales** (artefactos, orden lógico)? No añadas `needs:` por "simetría".
- [ ] ¿Alguien que lea el YAML entiende el grafo sin ver la UI? Si no, considera comentarios o refactor.
- [ ] ¿El pipeline sigue siendo correcto si alguien añade un job nuevo sin `needs:`? (Spoiler: por defecto queda al final de su stage, no en el grafo).

## 5. Antipatrón detectado en la vida real

Pipeline con 15 jobs en 3 stages, cada stage con `max_duration = 20 min` por un job lento. Deploy esperaba 60 min. Al añadir `needs:` apuntando al único job del que dependía realmente, el deploy bajó a 25 min. **Nadie había hecho el ejercicio** de preguntarse de qué depende cada job.
