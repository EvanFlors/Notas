# Actividad `cap-06-01-choose-cloud-adr`

Elegir el cloud default del capstone y firmar la ADR 0006.

## Qué vas a hacer

1. Abrir `terraform/README.md` (viene pre-firmada como ADR 0006 default de la academia).
2. Reemplazar la fecha `2026-10-20` por la fecha real del equipo y `Capstone maintainers` por los nombres del equipo.
3. Recalcular la tabla de criterios **con tus propios pesos** — no copies la del template.
4. Dejar explícito el cloud elegido en la sección **Decisión** (default sugerido: AWS). Si el equipo elige otro, marcá el estado como `superseded` o reescribí la ADR y dejala en `accepted`.
5. El estado final debe quedar en `accepted` (o `superseded` + nueva ADR en `accepted`).
6. Correr `bash tests/validate.sh` desde la raíz de esta actividad.

## Qué chequea el validador

- Que `terraform/README.md` existe.
- Que la ADR ya no está en estado `propuesta` (busca `accepted`).
- Que la fecha `YYYY-MM-DD` fue reemplazada.
- Que el placeholder `equipo del capstone` fue reemplazado.
- Que la Decisión nombra uno de `AWS`, `GCP` o `Azure`.

## Entregable

El `terraform/README.md` actualizado y comiteado en el repo del equipo.
