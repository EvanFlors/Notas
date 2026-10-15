# tf-11-02 — Recuperar un lock colgado en DynamoDB

## 1. Identificación

- **ID:** `tf-11-02-recover-stuck-lock`
- **Tecnología:** terraform
- **Módulo:** `11-remote-backends-and-locking`
- **Dificultad:** advanced
- **Duración estimada:** 45 min
- **Tipo:** independent

## 2. Contexto

Son las 03:40 AM. Un on-call anterior intentó aplicar un cambio en `app-payments` desde una laptop corporativa que se durmió a mitad del `terraform apply`. Nadie puede aplicar cambios ahora: cualquier `plan` o `apply` revienta con:

```
Error acquiring the state lock
Lock Info:
  ID:        f3a1c9e2-...
  Operation: OperationTypeApply
  Who:       alice@laptop
  Created:   2026-10-15 03:12:00 UTC
```

Tu misión: **diagnosticar** si el apply original está realmente muerto, **recuperar** el lock sin romper el state y **documentar** el incidente.

Es una actividad **independiente**: no te doy la solución paso a paso. Te doy la infraestructura simulada y los criterios de aceptación.

## 3. Objetivos

- Reproducir un lock colgado inyectando una fila directamente en la tabla DynamoDB.
- Verificar antes de desbloquear: ¿apply vivo? ¿state consistente?
- Ejecutar `terraform force-unlock <LOCK_ID>` solo cuando corresponde.
- Dejar un `/tmp/tf-11-02/postmortem.md` con una síntesis clara.

## 4. Prerrequisitos

- Haber completado `tf-11-01` (ya tienes bucket, tabla y state remoto).
- `terraform` / `tofu`, `aws` CLI.
- `MODE=local`: docker + localstack arriba.
- `MODE=live`: credenciales reales con permisos sobre S3+DDB.

## 5. Instrucciones

Trabaja en `/tmp/tf-11-02/`. Copia el starter:

```bash
mkdir -p /tmp/tf-11-02
cp -r courses/terraform/11-remote-backends-and-locking/activities/02-recover-stuck-lock/starter/* /tmp/tf-11-02/
cd /tmp/tf-11-02
```

### Lo que te damos

- Un stack mínimo (`main.tf`) con backend `s3`.
- `backend.hcl` apuntando al bucket y tabla de la actividad anterior.
- `scripts/inject-lock.sh` — inyecta una fila en DDB simulando el lock colgado.
- `postmortem.template.md` — plantilla a rellenar.

### Lo que tienes que hacer

1. **Simula el incidente**:
   ```bash
   MODE=local bash scripts/inject-lock.sh
   ```
   Esto inserta una fila en `tf-lock-tf11` con `LockID` apuntando a `tf-state-tf11/tf-11-02/terraform.tfstate` y `Info` con `Who=alice@laptop`.

2. **Reproduce el error**:
   ```bash
   terraform init -backend-config=backend.hcl
   terraform plan
   ```
   Deberías ver el error de lock.

3. **Investiga antes de desbloquear**:
   - Lee la fila completa:
     ```bash
     aws --endpoint-url=$AWS_ENDPOINT_URL_DYNAMODB dynamodb get-item \
       --table-name tf-lock-tf11 \
       --key '{"LockID":{"S":"tf-state-tf11/tf-11-02/terraform.tfstate-md5"}}'
     ```
   - ¿Quién, cuándo, qué operación?
   - ¿Hay escrituras recientes en el bucket? (`aws s3api list-object-versions ...`)
   - ¿Puedes confirmar que el proceso original está muerto? (en esta simulación, sí; en el mundo real, pregunta en el canal de on-call antes).

4. **Recupera el lock** con el comando apropiado (hint: no es `aws dynamodb delete-item` manual — hay una forma oficial que Terraform documenta y pide confirmación). Terraform imprimirá el `LockID` que extrajo del error cuando corras `plan`.

5. **Verifica**:
   - `terraform plan` ya no da el error.
   - El state remoto sigue consistente (`terraform state list` muestra lo esperado o vacío si nunca aplicaste algo en este path).
   - La fila ya no está en DDB.

6. **Rellena el post-mortem**:
   Copia `postmortem.template.md` a `postmortem.md` y rellénalo. El validador verifica que mencionas:
   - `LockID` extraído.
   - `Who` del lock original.
   - Comando usado para liberar (busca la palabra `force-unlock`).
   - Al menos una verificación hecha ANTES de desbloquear (p. ej. "comprobé que la laptop de Alice estaba fuera de red / que el runner de CI estaba terminado / que no había escrituras recientes al bucket").

7. **Valida**:
   ```bash
   MODE=local bash tests/validate.sh
   ```

## 6. Resultado esperado

- La fila de DDB fue borrada por `terraform force-unlock`.
- `/tmp/tf-11-02/postmortem.md` existe y menciona los campos requeridos.
- `terraform plan` corre sin errores.

## 7. Criterios de aceptación

- `tests/validate.sh` imprime `RESULT: PASS`.
- El post-mortem no es un placeholder vacío: tiene razonamiento tuyo.
- No usaste `aws dynamodb delete-item` manualmente (eso es un atajo que te saltas la trazabilidad; el validador no puede detectarlo directamente, pero sí comprueba que la celda está vacía y la mención del comando `force-unlock` en el postmortem).

## 8. Validación

```bash
MODE=local bash courses/terraform/11-remote-backends-and-locking/activities/02-recover-stuck-lock/tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿En qué escenarios `force-unlock` sería **catastrófico**? Describe dos.
2. ¿Qué pasa si usas `aws dynamodb delete-item` en vez de `force-unlock`? ¿Por qué no es equivalente?
3. ¿Cómo cambiaría tu respuesta si la actividad fuera en PROD y Alice estuviera de vacaciones (no responde)?
4. ¿Qué política operativa recomendarías para evitar que un apply se cuelgue así en primer lugar?

## 10. Extensiones

- Simula el "lock legítimamente en uso" lanzando dos `apply` casi simultáneos (añade un `time_sleep` al stack). Observa el error del segundo.
- Escribe un script que, dado un `LockID` colgado > 1h, mande una alerta a Slack con el campo `Who`.
- Usa `aws s3api list-object-versions` para rollback de un state que quedó corrupto.

## 11. Limpieza

```bash
cd /tmp/tf-11-02
terraform destroy -auto-approve || true
rm -rf /tmp/tf-11-02

# Si ya no vas a hacer más labs de tf-11, baja localstack:
# docker rm -f tf11-localstack
```
