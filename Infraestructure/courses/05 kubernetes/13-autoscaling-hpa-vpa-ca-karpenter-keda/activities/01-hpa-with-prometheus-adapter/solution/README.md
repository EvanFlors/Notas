# Solución de referencia — k8s-13-01

Script `run-solution.sh` ejecuta la actividad entera desde cero. Úsalo solo si te atascas; aprender es más valioso que llegar al OK.

## Qué hace

1. Crea el cluster kind.
2. Instala metrics-server y aplica el patch de `--kubelet-insecure-tls`.
3. Despliega `web` y el HPA.
4. Lanza un pod de carga en background que martillea el Service.
5. Espera ~2.5 min a que HPA escale.
6. Ejecuta `tests/validate.sh`.
7. Imprime el `describe hpa` final para inspección.

No corre la limpieza — eso lo haces tú para auditar el estado.

```bash
bash solution/run-solution.sh
```
