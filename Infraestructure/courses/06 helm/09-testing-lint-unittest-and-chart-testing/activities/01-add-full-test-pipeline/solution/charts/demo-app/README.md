# demo-app

Chart de referencia con pipeline de testing completa.

## Supported Kubernetes versions

El pipeline `ct install` corre sobre:

| Versión | Rol |
|---------|-----|
| `v1.31.0` | *n* — última estable |
| `v1.30.0` | *n-1* |
| `v1.29.0` | *n-2* — mínima soportada |

**Justificación**: política *n, n-1, n-2* siguiendo el calendario upstream de Kubernetes (≈ 3 minors vivas al mismo tiempo). Esto cubre a los consumidores que todavía no han actualizado al último release sin pagar el coste de probar toda la long tail de versiones. Si un consumidor empresarial fija una versión fuera de este rango, la soportamos sólo con best-effort (sin tests automáticos).
