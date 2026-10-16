# Ejemplo 03 — import-values + exports

Un chart padre `parent` necesita conocer el **puerto** y la **ruta de healthcheck** del subchart `backend` sin tener que escribir `.Values.backend.service.port` en todos sus templates.

Se usan dos modos:
- **child-parent** (explícito): copia `.Values.service` del subchart a `.Values.backendService` del padre.
- **implícito con `exports`**: el subchart declara `exports.endpoints` y el padre lo "aplana".

## Estructura
```
parent/
├── Chart.yaml                 # dependencies con import-values
├── values.yaml
├── templates/
│   └── gateway-cm.yaml        # consume .Values.backendService.*
└── charts/
    └── backend/
        ├── Chart.yaml
        ├── values.yaml        # define service.* y exports.endpoints
        └── templates/
            └── backend-cm.yaml
```

## Pasos

1. Render:
   ```bash
   helm template demo ./parent
   ```

2. Observar el ConfigMap `demo-gateway`:
   - `backendPort: "8080"` — vino del subchart `backend` por `import-values` child-parent.
   - `healthPath: "/healthz"` — vino de `exports.endpoints` por `import-values` implícito.
   - El padre nunca escribió `backend.service.port` en su template.

3. Override desde el padre: cambiar el puerto en `values.yaml` del padre bajo la clave `backend:`:
   ```yaml
   backend:
     service:
       port: 9090
   ```
   `backendService.port` del padre refleja `9090` tras el próximo render.

## Lectura

- `import-values` evita que el padre dependa de la **estructura interna** del subchart. Si mañana el subchart renombra `service.port` → `net.port`, basta con tocar la línea de `import-values` del padre.
- Los `exports` son útiles cuando un subchart quiere "exponer" un contrato estable (p. ej. endpoints) sin exigir al padre conocer su layout.
- Combinable con `global`: `global` es para valores que **entran** desde el padre; `import-values` es para valores que **salen** del subchart hacia el padre.
