# Operative — Starter

Este directorio contiene un workflow intencionalmente vulnerable e ineficiente
(`.github/workflows/ci.yml`) y una app Python mínima.

## Qué entregar

1. `.github/workflows/ci.yml` endurecido (reemplaza el starter completo).
2. `ADR.md` en la raíz del entregable con las decisiones tomadas (una decisión por sección: contexto / decisión / consecuencias).
3. `supply-chain.md` que demuestre el flujo SBOM + attestation + firma + verificación.
4. Opcional: `.github/dependabot.yml` para actualizar actions.

Debe ejecutar localmente (sin invocar GitHub) `operative/validate/run.sh`
apuntando al directorio de entregables y pasar todas las comprobaciones.

## Reglas

- Prohibido commitear secretos reales. Usar placeholders `${{ secrets.* }}`.
- Prohibido abrir cuentas AWS reales: migrar a OIDC se evalúa por configuración, no por ejecución.
- Todo prose en español, todo YAML/código en inglés.
