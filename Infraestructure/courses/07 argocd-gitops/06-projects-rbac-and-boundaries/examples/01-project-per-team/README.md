# Ejemplo 01 — Un `AppProject` por equipo

Dos equipos ficticios: **payments** y **checkout**. Cada uno con su propio project, sus propios namespaces, su propio repo whitelisteado.

## Qué demuestra

- Un `AppProject` por equipo con `sourceRepos`, `destinations`, whitelists mínimas.
- Que si una Application del project `team-payments` intenta desplegar en `checkout-prod`, Argo CD la rechaza *antes* de llegar al cluster.
- Que ambos projects pueden coexistir sin solaparse.

## Prerrequisitos

- `kind` y `kubectl` instalados.
- `argocd` CLI.
- Un cluster `kind` con Argo CD ya corriendo (ver `argo-02` del curso). Si no lo tienes, el script `apply.sh` **lo detecta y aborta con mensaje claro** — no instala Argo CD por ti.

## Archivos

- `project-team-payments.yaml` — `AppProject` para payments.
- `project-team-checkout.yaml` — `AppProject` para checkout.
- `app-payments-good.yaml` — Application legítima del equipo payments.
- `app-payments-bad.yaml` — Application del project payments que intenta ir a `checkout-prod`. **Argo CD debe rechazarla.**
- `apply.sh` — aplica todo y verifica el rechazo esperado.
- `cleanup.sh` — borra lo creado.

## Uso

```bash
cd examples/01-project-per-team
bash apply.sh
# ... observa la salida: la Application "bad" debe quedar en estado inválido o rechazarse
bash cleanup.sh
```

## Lectura clave

- Mira `project-team-payments.yaml`: `destinations[].namespace: payments-*`. Un glob restringe a namespaces del equipo.
- Mira `app-payments-bad.yaml`: `destination.namespace: checkout-prod`. El project **no lo contiene** → error esperado: `application destination ... is not permitted in project 'team-payments'`.

El error aparece como `conditions` en el status de la Application, no como fallo de `kubectl apply` del manifest de la Application (porque Argo CD la admite al nivel de API, pero la marca como inválida al reconciliar).
