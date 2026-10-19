# Ejemplo 02 — Canary con revisions (traffic split 90/10)

> Lectura y analisis. Objetivo: entender como funciona el **traffic split declarativo** entre dos revisions del mismo Container App.

## 1. El `main.tf` relevante

```hcl
resource "azurerm_container_app" "api" {
  name                         = "ca-api"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name

  # IMPORTANTE: "Multiple" habilita convivencia de revisions.
  revision_mode                = "Multiple"

  template {
    container {
      name   = "api"
      image  = "ghcr.io/example/api:v2"
      cpu    = 0.5
      memory = "1Gi"
    }
    min_replicas    = 1
    max_replicas    = 10
    # Sufijo explicito para auditoria. La revision quedara nombrada
    # ca-api--v2.
    revision_suffix = "v2"
  }

  ingress {
    external_enabled = true
    target_port      = 8000

    # 90% al estable, 10% al nuevo.
    traffic_weight {
      revision_suffix = "v1"
      percentage      = 90
    }
    traffic_weight {
      revision_suffix = "v2"
      percentage      = 10
    }
  }
}
```

## 2. Lectura clave

1. **`revision_mode = "Multiple"`** es la bandera que habilita que dos revisions reciban trafico al mismo tiempo. En `"Single"` solo la ultima estaria activa.
2. **`revision_suffix = "v2"`** es el nombre humano de esta revision. El nombre interno real es `ca-api--v2`. Si no lo das, Azure genera un sufijo random.
3. **`traffic_weight`** se repite N veces, una por revision. Los porcentajes deben sumar 100 (si no, el provider rechaza el plan).
4. **La revision `v1` no esta definida en este .tf** — ya existe en el estado del cloud por un apply anterior. Esta receta solo cambia los pesos; no toca v1.

## 3. Flujo tipico de un canary

Supongamos que hoy esta en prod `v1` al 100%:

```hcl
traffic_weight { revision_suffix = "v1", percentage = 100 }
```

### Paso 1 — publicar `v2` al 10%

```hcl
template { container { image = ":v2" } revision_suffix = "v2" }

ingress {
  traffic_weight { revision_suffix = "v1", percentage = 90 }
  traffic_weight { revision_suffix = "v2", percentage = 10 }
}
```

Monitorea p99, error rate, custom metrics por 15-30 min.

### Paso 2 — subir a 50%

```hcl
traffic_weight { revision_suffix = "v1", percentage = 50 }
traffic_weight { revision_suffix = "v2", percentage = 50 }
```

### Paso 3 — promover a 100%

```hcl
traffic_weight { revision_suffix = "v2", percentage = 100 }
# v1 queda deactivated automaticamente (sin trafico).
```

### Rollback inmediato si algo rompe

```hcl
traffic_weight { revision_suffix = "v1", percentage = 100 }
```

El DNS **no cambia** en ningun paso. Las replicas de la revision deactivated se destruyen tras ~5-10 min; el app en si queda intacto.

## 4. Operacion via CLI (alternativa a Terraform)

Para experimentar sin reapply:

```bash
az containerapp revision set-mode \
    --name ca-api --resource-group rg-fastapi-demo --mode multiple

az containerapp ingress traffic set \
    --name ca-api --resource-group rg-fastapi-demo \
    --revision-weight ca-api--v1=90 ca-api--v2=10
```

En entornos reales **mezcla** los dos enfoques es mala idea (drift). Elige uno.

## 5. Diferencias con AWS

- **ECS/Fargate** hace canary via CodeDeploy BlueGreen con dos target groups + ALB listener rule — mucho mas chasis.
- **App Runner** no hace canary granular, solo rolling.
- **Container Apps** lo hace **en el recurso mismo**, declarativo, sin orquestar ALB ni listeners. Es el feature matador del servicio.

## 6. Errores comunes

- **Pesos que no suman 100**: el plan falla.
- **`revision_mode = "Single"` + dos `traffic_weight`**: Azure ignora el segundo o aplica raro. Siempre `Multiple` para canary.
- **No incrementar `revision_suffix`**: cada apply con cambios al `template` crea una revision nueva. Si no fijas `revision_suffix`, acabas con `ca-api--rev-abc123` que no significa nada en los logs.
