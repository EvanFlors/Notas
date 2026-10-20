# Ejemplo 03 — Pinning de versión de la library

> Lectura. Objetivo: entender cuatro formas de referenciar una Shared Library y por qué solo dos son aceptables en producción.

## Variante A — sin versión (default del admin)

```groovy
@Library('acme-ci') _
standardBuild(image: 'checkout-api')
```

Qué pasa:

- Carga la **versión por defecto** configurada en `Manage Jenkins > System > Global Pipeline Libraries` para esta library. Casi siempre es `main`.
- Comportamiento: cada build puede traer código distinto sin que el `Jenkinsfile` cambie.

Veredicto: **inaceptable en prod**. Dificulta auditoría ("¿qué código corrió en el build #142?") y expone a cambios no revisados en consumidores downstream.

## Variante B — pin a branch

```groovy
@Library('acme-ci@main') _
standardBuild(image: 'checkout-api')
```

Qué pasa:

- Explícitamente la última de `main` en el momento del build.
- Mejor que la Variante A por hacer explícita la elección, pero **comportamiento idéntico** (se mueve bajo tus pies).

Veredicto: **inaceptable en prod**. Útil durante desarrollo de la library (p. ej. `@Library('acme-ci@feature/new-step')` para probar un cambio sin taggearlo).

## Variante C — pin a tag

```groovy
@Library('acme-ci@v1.3.0') _
standardBuild(image: 'checkout-api')
```

Qué pasa:

- Carga **exactamente** el commit al que apunta `v1.3.0` en el momento del tagging.
- Un tag anotado en Git es (en la práctica) **inmutable** siempre que haya branch protection sobre `v*`.
- Bumpear la versión requiere cambiar el `Jenkinsfile` → PR revisable → auditable.

Veredicto: **recomendado**. Es la variante para prod. La "fricción" de bumpear es *feature*, no bug.

## Variante D — pin a SHA

```groovy
@Library('acme-ci@a1b2c3d4') _
standardBuild(image: 'checkout-api')
```

Qué pasa:

- Un SHA de commit, inmutable por definición.
- Más seguro aún que un tag (los tags podrían moverse si no hay branch protection).
- Menos legible: nadie sabe "qué versión semver" es ese SHA.

Veredicto: **útil cuando no confías en los tags** o cuando quieres pin pre-release durante hardening.

## Resumen operacional

| Variante | Uso recomendado |
|----------|-----------------|
| A (sin pin) | Nunca en código nuevo. Legacy a migrar. |
| B (`@branch`) | Desarrollo activo de la library, feature flags. |
| C (`@tag`) | **Default para producción.** |
| D (`@sha`) | Rollout canario de la library o entornos con alta exigencia regulatoria. |

## Admin overrides a tener en cuenta

En la configuración de la library (controller):

- **Allow default version to be overridden**: necesario para que los consumidores puedan declarar su propio `@tag`. Si no, el admin "obliga" la default.
- **Include @Library changes in job recent changes**: cuando lo activas, un bump de `v1.3.0 → v1.4.0` aparece en el changelog del build (vía SCM). Trazabilidad fuerte.
- **Load implicitly**: carga la library **sin** `@Library` en el `Jenkinsfile`. **Anti-patrón** fuera de casos muy controlados: convierte una dependencia explícita en magia global.
