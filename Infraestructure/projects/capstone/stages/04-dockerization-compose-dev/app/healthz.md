# Contrato del endpoint `/healthz`

> Este archivo documenta el contrato que la app FastAPI (producida en la etapa 1
> y consumida por el `HEALTHCHECK` del Dockerfile y por `depends_on` de Compose)
> debe cumplir. **No es código ejecutable** de esta etapa; es el contrato que
> la implementación en `app/main.py` del repositorio real debe respetar.

## Semántica

| Estado | HTTP | Body (JSON) | Significado |
|--------|------|-------------|-------------|
| Sano | `200` | `{"status":"ok","db":"ok"}` | Proceso vivo + conexión a Postgres válida |
| Degradado (DB caída) | `503` | `{"status":"degraded","db":"down"}` | Proceso vivo pero sin DB |
| Startup | `503` | `{"status":"starting"}` | App todavía inicializando |

## Reglas

1. **No bloquear.** El handler debe responder en < 1 s; el chequeo de DB usa un
   `SELECT 1` con `statement_timeout=500ms`.
2. **No cachear.** Headers `Cache-Control: no-store`.
3. **Sin auth.** El endpoint es público para que `kubelet` / ECS / Compose lo
   puedan hitar sin credenciales.
4. **Idempotente y side-effect free.** No incrementa métricas de negocio ni
   escribe en logs de nivel `INFO` por cada hit.

## Snippet de referencia (FastAPI)

```python
# app/main.py — fragmento ilustrativo. La implementación real vive en etapa 1.
from fastapi import FastAPI, Response
from sqlalchemy import text

app = FastAPI()

@app.get("/healthz")
def healthz(response: Response):
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return {"status": "ok", "db": "ok"}
    except Exception:
        response.status_code = 503
        return {"status": "degraded", "db": "down"}
```

## Validación manual

```bash
curl -fsS -o /dev/null -w "%{http_code}\n" http://localhost:8000/healthz
# Esperado: 200
```

El `HEALTHCHECK` del Dockerfile hace exactamente lo mismo pero usando `urllib`
para evitar depender de `curl` dentro de la imagen distroless.
