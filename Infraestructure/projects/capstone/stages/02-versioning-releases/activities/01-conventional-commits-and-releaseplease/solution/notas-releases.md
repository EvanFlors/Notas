# Notas — Mapeo de Conventional Commits a SemVer

- **`feat:` sobre `0.0.0` da `0.1.0`, no `0.0.1`.** El manifest arranca en
  `0.0.0` (pre-1.0.0) y `release-please` está configurado con
  `bump-minor-pre-major: true` + `bump-patch-for-minor-pre-major: false`, así
  que un `feat` siempre sube el *minor* durante la fase 0.x. Es coherente con
  SemVer §4: en 0.y.z las APIs se consideran inestables y cada feature puede
  romper compatibilidad.
- **Salto a `1.0.0`.** Ocurre cuando declaramos la API estable: lo forzamos con
  un commit que incluya el footer `Release-As: 1.0.0`, o esperando al primer
  commit con `!` / `BREAKING CHANGE:` (que, por regla general, en 0.x sube
  minor, pero `release-please` promueve a 1.0.0 si lo pedimos explícitamente
  con la etiqueta `autorelease: pending` + override).
- **Qué dispara `major`.** Un commit con `type!: ...` (ej.
  `feat!: remove /notes v1`) **o** cualquiera cuyo footer contenga
  `BREAKING CHANGE: <descripción>`. Una vez en 1.y.z, ese commit sube de
  `1.4.2` a `2.0.0`.
- **Commits que no bumpean**: `docs`, `test`, `build`, `ci`, `chore`,
  `refactor` (sin `!`). Siguen apareciendo en el Release PR, pero algunos
  (los marcados `hidden: true` en la config) no salen al `CHANGELOG.md`.
