# Ejemplo 03 — Reproducibilidad con `Chart.lock`

## Qué muestra

Qué fija exactamente `Chart.lock`, qué pasa si se borra `charts/` y se usa `build` vs `update`, y cómo el lock protege contra "dos checkouts, dos versiones distintas".

Usa un **subchart local** (`chart-repo/`) servido con `helm repo index`, así que es **100% offline** una vez el script está en disco (no requiere Bitnami).

## Requisitos

- Helm ≥ 3.14.
- Puerto libre para servir un repo local (opcional; aquí usamos `file://` para evitarlo).

## Ejecutar

```bash
bash run.sh
```

El script:

1. Crea un chart "biblioteca local" (`mydep`) en dos versiones: `1.0.0` y `1.1.0`.
2. Empaqueta ambas y genera `index.yaml` en `/tmp/helm-ex-03/repo/`.
3. Crea un chart padre `myapp` que declara `mydep` con rango `~1.0.0` (es decir, acepta 1.0.x pero no 1.1.x).
4. Ejecuta `helm dependency update` → resuelve a `1.0.0`, escribe `Chart.lock`.
5. Publica una **nueva** versión `1.0.1` en el repo local y regenera `index.yaml`.
6. Simula "segundo checkout": copia el padre a otro directorio y hace `helm dependency build` (lee lock) → se queda en `1.0.0`, no en `1.0.1`.
7. En el padre original, hace `helm dependency update` → sube a `1.0.1` y reescribe lock.
8. Imprime la diferencia entre `Chart.lock` antes/después.

## Qué observar

- Tras el paso 6, los dos "checkouts" **convergen** a la misma versión porque ambos consultan el mismo lock. Sin lock, no.
- `helm dependency build` **nunca** resuelve rangos nuevos: lee el lock tal cual.
- `helm dependency update` consulta el repo y puede subir dentro del rango permitido en `Chart.yaml`.
- Si borrases `Chart.lock` y volvieras a hacer `build`, falla con `Chart.lock is out of sync`.

## Limpieza

```bash
bash cleanup.sh
```
