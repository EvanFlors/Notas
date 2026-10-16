# otel-07-02 — Fix broken propagation (debug)

## 1. Identificación
- **ID:** `otel-07-02-fix-broken-propagation`
- **Tecnología:** opentelemetry
- **Módulo:** `07-context-propagation-across-services`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** debug

## 2. Contexto
El starter contiene dos servicios (A y B) que **ya tienen OTel configurado y emiten spans**. Al correrlos, el trace **se corta** entre A y B — cada servicio emite spans con `trace_id` distinto. Tu trabajo es diagnosticar la causa y corregir el código.

Son los síntomas clásicos de propagación rota en producción, pero concentrados en 2 archivos pequeños. Hay **más de un bug**: resuélvelos todos.

## 3. Objetivos
- Diagnosticar causas de propagación rota (ausencia de `inject`/`extract`, propagator incompatible, carrier perdido).
- Aplicar fixes mínimos sin reescribir los servicios.
- Validar el fix con el harness provisto.

## 4. Prerrequisitos
- Python 3.10+.
- `pip install opentelemetry-sdk`.
- Puerto `8820` libre (configurable con `PORT`).

Sin costos.

## 5. Instrucciones (no se revela la solución)
1. Lee los dos archivos del `starter/`.
2. Corre `bash tests/validate.sh`. El output debería ser `FAIL` describiendo el síntoma.
3. Inspecciona los logs de ambos servicios: ¿qué ves en los spans? ¿Hay `parent_id` en el span de B? ¿El header `traceparent` llega al server? Añade `print()` si hace falta.
4. Repasa el checklist mental:
   - ¿El cliente llama a `inject`?
   - ¿El server llama a `extract` sobre los headers correctos?
   - ¿El propagator global está alineado entre ambos procesos?
   - ¿El carrier sobrevive el transporte (nombres case-sensitive, bytes vs str)?
5. Aplica el **fix mínimo**. No reescribas los servicios; cambia solo lo necesario.
6. Vuelve a correr `bash tests/validate.sh` hasta ver `OK:`.
7. Documenta en 2-3 frases qué era cada bug y por qué el fix funciona.

Pista general (si llevas 20 minutos atascado): el starter tiene **dos** problemas independientes. Uno vive en el lado del productor y otro en el lado del consumidor.

## 6. Resultado esperado
`tests/validate.sh` termina con exit `0` y mensaje `OK:`. Ambos servicios comparten `trace_id` y el span de B tiene `parent_id` no-cero.

## 7. Criterios de aceptación
- Fix mínimo (no reescribir servicios).
- Documentación de los dos bugs identificados.
- Validación automatizada OK.

## 8. Validación
```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexión
- ¿Por qué el nombre `TraceParent` (CamelCase) rompe la propagación aunque HTTP sea case-insensitive?
- ¿Cómo detectarías este bug en producción sin acceso a los logs del servidor B? (Pista: `tracestate` + consistencia).
- ¿Qué métrica/alerta pondrías para detectar propagación rota a nivel de plataforma?

## 10. Extensiones
- Añade un test negativo que revierta tu fix y confirme que falla.
- Reemplaza el carrier dict por un objeto custom (`class HeaderDict`) y adapta el código.
- Habilita `OTEL_PROPAGATORS=b3,baggage` en ambos servicios y confirma que sigue funcionando.

## 11. Limpieza
`tests/validate.sh` limpia su proceso en background y temporales. Manual: `pkill -f service_b.py`.
