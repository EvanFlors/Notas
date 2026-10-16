# otel-07-01 — Two services, end-to-end trace

## 1. Identificación
- **ID:** `otel-07-01-two-services-end-to-end-trace`
- **Tecnología:** opentelemetry
- **Módulo:** `07-context-propagation-across-services`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto
Vas a construir dos microservicios Python (`service_a`, `service_b`). `service_a` recibe un request HTTP y, dentro del handler, invoca `service_b` para procesarlo. Debes conseguir que **ambos spans compartan el mismo `trace_id`**, aun cuando no uses ninguna instrumentation library automática — solo `inject` / `extract` manual.

Esto refleja la situación real en la que tu framework no está instrumentado (middleware custom, Lambda handlers, workers, etc.) y la propagación debe hacerse a mano.

## 3. Objetivos
- Serializar el context actual en un carrier de headers con `inject`.
- Reconstruir un context remoto con `extract` y abrir un span como su hijo.
- Verificar programáticamente que `trace_id` sobrevive el hop HTTP.

## 4. Prerrequisitos
- Python 3.10+.
- `pip install opentelemetry-sdk` (API, SDK y propagators W3C vienen incluidos).
- `curl` para probar manualmente (opcional).
- Puerto `8810` libre (configurable con `PORT`).

Sin costos. Todo corre en localhost.

## 5. Instrucciones
1. Lee `starter/service_b.py`. Es un server stdlib (`http.server`) que ya extrae el context y abre un span como hijo. Déjalo intacto.
2. Edita `starter/service_a.py`. Donde dice `# TODO: inject here`, serializa el context actual en el dict `headers` con `inject(headers)`.
3. Opcionalmente, abre un span `A.handle` con `tracer.start_as_current_span` **antes** del `inject`, para que el context tenga un span como current.
4. Corre `bash starter/run.sh`. Debería imprimir `OK: trace_id matches end-to-end`.
5. Si no funciona, revisa `tests/validate.sh` para ver qué espera.

## 6. Resultado esperado
Ambos servicios imprimen spans con **el mismo** `trace_id` (hex 32 chars). El `parent_id` del span de B apunta a un span emitido por A.

## 7. Criterios de aceptación
- `tests/validate.sh` termina con exit `0` y mensaje `OK:`.
- El código de `service_a.py` llama a `inject(headers)` dentro del contexto de un span.
- No se hardcodea el `traceparent`; se construye via API.

## 8. Validación
```bash
bash tests/validate.sh
```
El script arranca `service_b` en background, ejecuta `service_a` como cliente, captura los span logs y verifica el match de `trace_id`.

## 9. Preguntas de reflexión
- ¿Qué pasa si llamas a `inject(headers)` **fuera** de un `start_as_current_span`? ¿Qué contiene el carrier?
- ¿Qué debería ocurrir si cambias `OTEL_PROPAGATORS=b3` en una terminal y no en la otra?
- ¿Por qué el span de B necesita el argumento `context=ctx` y no basta con que esté "después" del `extract`?

## 10. Extensiones
- Cambia el propagator global a B3 (`b3,baggage`) en ambos servicios y verifica que sigue funcionando.
- Añade un header `baggage: tenant=acme` en el cliente y léelo en el server con `baggage.get_baggage("tenant")`.
- Reemplaza `http.server` por FastAPI + `httpx` + sus instrumentations y confirma que el trace sigue continuo sin tocar `inject`/`extract`.

## 11. Limpieza
`tests/validate.sh` mata su proceso en background y borra sus temporales. Si lo corres manualmente, `pkill -f "service_b.py"`.
