# ADR 002 — Adopción de collections AWS (community.aws vs amazon.aws)

> Documento de referencia. Es **una** respuesta razonable, no la única.

## Estado

Aceptado.

## Contexto

Hemos consolidado playbooks AWS que viven en 4 repos distintos y mezclan `amazon.aws` y `community.aws` sin criterio. Resultado: dos repos pinean versiones distintas de la misma collection, un tercer repo usa un módulo de `community.aws` que ya existe en `amazon.aws` con mejor cobertura, y nadie sabe cuál es la elección por defecto. Tenemos **Red Hat Ansible Automation Platform (AAP)** contratada, por lo que Automation Hub (certified) es accesible. Operamos en Europa (`eu-west-1`, `eu-central-1`) y el pin de `ansible-core` corre en `>=2.17,<2.19`.

Necesitamos una **regla operativa** que un nuevo ingeniero pueda aplicar sin preguntar.

## Decision

**Regla**: `amazon.aws` es la elección por defecto para cualquier módulo AWS. `community.aws` se usa **solo** cuando el módulo no existe en `amazon.aws` y migrar a un fork propio no se justifica. Toda collection externa va **pineada por versión exacta** en `collections/requirements.yml`. La fuente primaria es **Automation Hub** (certified); **Galaxy público** actúa de fallback para `community.*`.

Comparación por los 6 criterios de adopción:

| Criterio | `amazon.aws` | `community.aws` |
|----------|---------------|------------------|
| Mantenimiento | Red Hat + AWS. Releases regulares, SLA via Red Hat Support. | Comunidad amplia. Releases frecuentes pero sin SLA. |
| Cobertura | Núcleo AWS (EC2, S3, IAM, VPC, RDS, Lambda, inventory `aws_ec2`). Lo que un 80% de playbooks necesita. | Rellena huecos (CloudWatch Logs Insights, servicios menos usados, workarounds). |
| Dependencias upstream | `boto3`, `botocore` con rangos declarados en `meta/runtime.yml`. Compatibilidad probada contra ansible-core soportados. | Mismas Python deps; menos matriz de testing. |
| Licencia | GPL-3.0-or-later. Compatible con nuestra política. | GPL-3.0-or-later. Idem. |
| Certificada / firmada | **Sí** (certified, firmada GPG en Automation Hub). | **No**. En Galaxy público sin firma. |
| Namespace / propietario | `ansible-collections/amazon.aws`, mantenedores Red Hat + AWS. | `ansible-collections/community.aws`, mantenedores comunidad. |

**Patrón de rollback**: cuando aparezca un bug en un módulo (p. ej. `s3_object` en una `community.aws 7.0.0`), el flujo es:

1. **Pin** a la versión previa estable en `collections/requirements.yml` (`community.aws == 6.5.3`).
2. Reinstalación limpia: `rm -rf ./collections && ansible-galaxy collection install -r collections/requirements.yml -p ./collections`.
3. Issue upstream con repro mínima.
4. PR de migración cuando el fix esté publicado.

Sin pin, el bug llega a prod en el siguiente deploy. Con pin, tenemos semanas para migrar sin presión.

## Consecuencias

Positivas:

- Un ingeniero nuevo tiene una regla clara en lugar de 4 convenciones por repo.
- `amazon.aws` certified → SLA de Red Hat si algo rompe en prod.
- Firma GPG → podemos afirmar en auditoría que la collection instalada es la publicada por Red Hat.
- Pin exacto → reproducibilidad perfecta entre máquinas de developers y CI.

Negativas:

- Dos collections conviven en el repo, con posibilidad de solapamiento de módulos. Hay que mantener un pequeño mapping "para X, usa `amazon.aws.X`; para Y, usa `community.aws.Y`".
- `amazon.aws` evoluciona con breaking changes (7.x → 8.x renombró parámetros en `ec2_vpc_net`). El pin exacto cuesta tiempo de upgrade periódico.
- Dependencia de la subscripción AAP. Si la perdemos, caemos a Galaxy público (menor firma / soporte).

## Alternativas descartadas

### Alternativa 1 — Usar solo `community.aws`

Rechazada. Sin firma GPG y sin SLA, no cumple el requisito de auditoría. Además, la cobertura de `community.aws` para el núcleo (EC2, S3, IAM) es inferior a `amazon.aws`, duplicando trabajo.

### Alternativa 2 — Escribir módulos propios en una collection interna `mycorp.aws`

Rechazada por ahora. Reescribir `ec2_instance` o `s3_object` no aporta valor frente a `amazon.aws` y añade ~2 FTE de mantenimiento continuo. Reservamos esta vía para casos muy específicos (p. ej. un wrapper opinated sobre un servicio interno). Un fork propio **solo** se justifica cuando `amazon.aws` + `community.aws` juntas no cubren el caso **y** el esfuerzo de contribuir upstream está bloqueado.

### Alternativa 3 — Llamar `boto3` directo desde `script` modules

Rechazada. Pierdes idempotencia nativa, pierdes el `check` mode, y acabas reescribiendo lo que `amazon.aws` ya hace probado. Antipatrón.

---

## Revisión

Esta decisión se revisa en 12 meses o antes si:

- Red Hat deja de certificar `amazon.aws`.
- Aparece una collection `aws.cloud` o similar con cobertura competitiva.
- Perdemos la subscripción AAP.
- La relación de módulos "solo-en-community" supera el 20% de nuestro uso real.
