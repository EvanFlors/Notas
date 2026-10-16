# 03 — ThreadPoolExecutor context copy

El bug más común en apps Python con threads: un span abierto en el hilo principal **no** es visible desde los workers de un `ThreadPoolExecutor`. Resultado: el worker emite spans root y el trace se parte.

Dos scripts contrastan ambos comportamientos:

- `broken.py` → `executor.submit(do_work)` directo. El span del worker sale sin parent.
- `fixed.py` → `executor.submit(ctx.run, do_work)` con `contextvars.copy_context()`. El span del worker queda bajo el parent correcto.

## Cómo correrlo

```bash
bash run.sh
```

El script valida que:
- `broken.py` produce **dos** `trace_id` distintos.
- `fixed.py` produce **un solo** `trace_id` compartido.
