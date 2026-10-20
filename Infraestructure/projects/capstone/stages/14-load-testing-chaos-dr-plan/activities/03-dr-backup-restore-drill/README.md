# Actividad 03 — DR backup + restore drill (debug)

## 1. Identificacion

- **ID:** `cap-14-03-dr-backup-restore-drill`
- **Tecnologia:** `capstone`
- **Modulo:** `14-load-testing-chaos-dr-plan`
- **Tipo:** debug

## 2. Contexto

Tener un backup que nunca restauraste es equivalente a no tenerlo. Este drill descubre si el procedimiento documentado funciona *hoy*, con el tooling actual.

## 3. Objetivos

- Correr `postgres-backup.sh` y verificar que el archivo es legible por `pg_restore`.
- Correr `postgres-restore-drill.sh` y leer el drill log.
- Medir RTO empirico y compararlo con el DR-PLAN. Si > 30 min: declarar failed drill.

## 4. Prerrequisitos

- Postgres corriendo en el namespace `app` (STS `postgres-0`).
- `kubectl` autenticado. `pg_restore` opcional en el host (si no, el backup se asume valido por el `pg_dump` custom-format).

## 5. Instrucciones

1. Insertar al menos 1 fila en la tabla `items` desde la app para que haya data interesante que restaurar.
2. Correr backup:

   ```bash
   bash ../../dr/postgres-backup.sh
   ```

3. Correr drill:

   ```bash
   bash ../../dr/postgres-restore-drill.sh
   ```

4. Leer `../../backups/drill-log.md` y copiar la linea producida en `drill-report.md` seccion `## Resultado`.
5. Comparar RTO medido con el target (30 min) en seccion `## Comparacion vs DR-PLAN`.

### 5.5 Pistas

- Si `pg_restore` se queja de la BD "no existe" dentro del pod drill, revisa que el ENV `POSTGRES_DB` coincida con la DB del dump.
- Si el drill borra el namespace antes de que puedas inspeccionar algo, re-corre con `KEEP_NS=1`.

## 6. Resultado esperado

- `drill-report.md` con las secciones Resultado + Comparacion vs DR-PLAN.
- Al menos una linea en `backups/drill-log.md` con `verdict=OK`.

## 7. Criterios de aceptacion

- [ ] Scripts ejecutables (`chmod +x`).
- [ ] Scripts manejan SKIP si falta kubectl / backups.
- [ ] `drill-report.md` llenado.
- [ ] `validate.sh` termina con `RESULT: 0 issue(s)`.

## 8. Validacion

```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexion

1. ¿Que operacion dentro del drill domina el RTO: pull de la imagen, restore de los datos, o el wait de readiness?
2. ¿Como harias el drill mas rapido sin bajar la rigurosidad?
3. ¿Que pasa si la version mayor de Postgres cambia entre backup y restore?

## 10. Limpieza

```bash
rm -rf ../../backups/
```
