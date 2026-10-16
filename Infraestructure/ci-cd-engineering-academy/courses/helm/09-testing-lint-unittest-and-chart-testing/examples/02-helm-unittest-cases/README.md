# Ejemplo 02 — Casos de helm-unittest

Chart `demo-app` con una suite de `helm-unittest` que cubre los **5 edge cases canónicos** de values:

1. **Default values** — nada seteado, debe producir replicas=1 y la service default.
2. **Override completo** — `image.repository` y `image.tag` cambian, salen en el `image:` final.
3. **Lista vacía** — `extraEnv: []` → el campo `env:` NO aparece en el container.
4. **Nil** — `ingress.hosts: null` → el `Ingress` no se renderiza.
5. **Flag booleano** — `autoscaling.enabled=true` → aparece un `HorizontalPodAutoscaler`; con `false` NO aparece.

## Estructura

```
demo-app/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml      ← se renderiza condicional
│   └── hpa.yaml          ← se renderiza condicional
└── tests/
    ├── deployment_test.yaml
    ├── ingress_test.yaml
    └── hpa_test.yaml
```

## Correr

Requiere `helm` + plugin `helm-unittest`:

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest   # una vez
helm unittest demo-app
```

Salida esperada: todos los tests en verde. Si cambias `templates/deployment.yaml` para que ignore `.Values.replicaCount`, el test "default replica count" debería fallar — pruébalo.

## SKIP graceful

Si no tienes el plugin: `helm unittest` imprime `Error: unknown command "unittest"`. En CI, la condición típica es que el plugin siempre esté instalado antes del step; en local, instálalo o salta este ejemplo.
