# Actividad 02 — Chaos ligero con chaos-mesh (pod-kill + latency + cpu-stress)

## 1. Identificacion

- **ID:** `cap-14-02-chaos-mesh-pod-kill-latency-cpu`
- **Tecnologia:** `capstone`
- **Modulo:** `14-load-testing-chaos-dr-plan`
- **Tipo:** independent

## 2. Contexto

El sistema tiene healthchecks, replicas, HPA y alertas. ¿Realmente funcionan cuando algo falla? Este es el punto del chaos engineering: validar las defensas antes de que la realidad lo haga.

## 3. Objetivos

- Correr los 3 experimentos (pod-kill, latency-inject, cpu-stress) con blast radius acotado.
- Observar en Grafana y en los eventos de kubectl la respuesta del sistema.
- Documentar en `experiments.md` que paso, cuanto tardo en recuperarse y que alerta disparo.

## 4. Prerrequisitos

- chaos-mesh instalado en el cluster: `helm install chaos-mesh chaos-mesh/chaos-mesh -n chaos-mesh --create-namespace`.
- Un load generator opcional (actividad 01) corriendo en segundo plano para ver el efecto bajo trafico.

## 5. Instrucciones

1. Verificar que chaos-mesh esta sano: `kubectl get pods -n chaos-mesh`.
2. Correr los experimentos uno por uno:

   ```bash
   bash ../../chaos/run-experiment.sh pod-kill
   bash ../../chaos/run-experiment.sh latency-inject
   bash ../../chaos/run-experiment.sh cpu-stress
   ```

3. Durante cada experimento, mirar: `kubectl -n app get events --watch`, Grafana, alertas.
4. Para cada experimento, llenar en `experiments.md` las secciones del template.

### 5.5 Pistas

- Si pod-kill no "se nota", probablemente tienes 2+ replicas y rolling restart suave. Esta bien — anotalo como *hallazgo*, no como fallo.
- Si latency-inject hace fallar el healthcheck, revisa si el probe tiene un timeout razonable (<= 1 s para 200 ms de latencia inducida).

## 6. Resultado esperado

- `experiments.md` lleno con los 3 experimentos documentados.
- Validator pasa.

## 7. Criterios de aceptacion

- [ ] Los 3 YAMLs (`pod-kill.yaml`, `latency-inject.yaml`, `cpu-stress.yaml`) existen y son chaos-mesh.org CRDs validas.
- [ ] Cada YAML limita el selector al namespace `app`.
- [ ] `experiments.md` cubre los 3 experimentos.
- [ ] `validate.sh` termina con `RESULT: 0 issue(s)`.

## 8. Validacion

```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexion

1. ¿Que experimento te sorprendio mas y por que?
2. ¿Que agregarias al runbook de produccion a raiz de lo que descubriste?
3. ¿Como harias un experimento mas destructivo *con seguridad* (p. ej. kill de postgres)?

## 10. Limpieza

```bash
kubectl delete -f ../../chaos/ --ignore-not-found
```
