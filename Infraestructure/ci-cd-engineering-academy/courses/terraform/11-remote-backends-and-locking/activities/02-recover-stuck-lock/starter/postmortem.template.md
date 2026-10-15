# Post-mortem: lock colgado en `tf-11-02`

## Resumen

<una línea con qué pasó y qué hiciste>

## Datos del lock

- **LockID**: <copia el LockID exacto desde el error de terraform>
- **Who**: <quién figuraba como dueño del lock>
- **Operación**: <OperationType...>
- **Creado**: <timestamp>

## Verificaciones ANTES de desbloquear

Lista al menos una verificación concreta que hiciste para confirmar que era seguro desbloquear
(ej.: "confirmé con Alice por Slack que su laptop se durmió; verifiqué en S3 que no hubo
`PutObject` sobre el state en la última hora").

- 
- 

## Acción

Comando ejecutado para liberar el lock (incluir salida esperada):

```
terraform force-unlock <...>
```

## Verificación posterior

- [ ] `terraform plan` corre sin error
- [ ] La fila ya no está en DynamoDB
- [ ] `terraform state list` refleja la realidad

## Causa raíz y acción preventiva

Qué provocó el cuelgue y qué cambiarías para que no vuelva a pasar (política de CI, timeouts,
runners efímeros, retries, etc.).
