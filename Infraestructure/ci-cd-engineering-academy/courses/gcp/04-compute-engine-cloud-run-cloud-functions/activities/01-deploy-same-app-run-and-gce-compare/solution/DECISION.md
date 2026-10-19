# DECISION — Cloud Run vs Compute Engine para la API del capstone

## Contexto

La API es HTTP, stateless, en Python/FastAPI. Trafico esperado: bursty, con
largos periodos de inactividad en horas no-habiles. El equipo tiene 2
ingenieros y no quiere gestionar sistema operativo ni parches de Linux.

## Criterios comparados

| Criterio | Cloud Run | Compute Engine (MIG) |
|----------|-----------|----------------------|
| Coste en reposo | **~0** (scale-to-zero) | Pago 24/7 de >=1 VM aunque no haya trafico |
| Cold start | 100 ms - 1 s si min_instances=0; eliminable con min_instances>=1 | Nulo (VM siempre caliente) pero `target_size>=2` paga doble |
| Control del SO | Nulo (gVisor sandbox) | Total (daemons, drivers, kernel) |
| Operaciones (patch, SSH, upgrade) | Nulas | OS Login + patch management requerido |
| Deploy nuevo + rollback | Revision inmutable + `traffic{}` cambia routing | Rolling update del MIG, mas lento |

## Decision

**Elegimos Cloud Run.** El workload es exactamente aquello para lo que Cloud
Run esta disenado: HTTP stateless, bursty, sin requisitos de SO. Ganamos
scale-to-zero (coste en reposo ~0), rollback atomico via traffic splitting
y cero gestion de SO. La contrapartida (sandbox gVisor, cold start) es
aceptable y mitigable con `min_instance_count = 1` si el p99 lo exige.

Reconsiderariamos GCE solo si:

- La app necesitara acceso a hostNetwork, `/dev/net/tun` o drivers.
- El trafico fuera sostenido 24/7 cerca del 100% de utilizacion de la VM.
- Hubiera un requisito de compliance que prohibe multi-tenant (y Confidential
  Space / sole-tenant node no bastara).
