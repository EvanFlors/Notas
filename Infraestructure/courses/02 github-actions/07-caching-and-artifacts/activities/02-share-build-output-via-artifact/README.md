# Actividad 02 — Compartir el output de `build` entre jobs vía artifact v4

## 1. Identificación

- **ID:** `gha-07-02-share-build-output-via-artifact`
- **Tecnología:** `github-actions`
- **Módulo:** `gha-07-caching-and-artifacts`
- **Dificultad:** intermediate
- **Duración estimada:** 45–60 min
- **Tipo:** guided-lab

## 2. Contexto

Te entregan un workflow **monolítico**: un único job `all-in-one` que builda, testea y deploya. Es el patrón más común en repos jóvenes y el primero que se vuelve problemático:

- No puedes paralelizar `test` con otros checks.
- `deploy` no garantiza que esté deployando *lo testeado* (podría re-buildear algo distinto).
- No tienes rastreabilidad del output construido.

Tu tarea: refactorizarlo en **tres jobs encadenados** — `build`, `test`, `deploy` — compartiendo el bundle `dist/` como un artifact v4.

## 3. Objetivos

Al terminar:
- El workflow tiene **exactamente** tres jobs: `build`, `test`, `deploy`.
- `test` y `deploy` declaran `needs:` apuntando (transitivamente) a `build`.
- `build` tiene **un** `actions/upload-artifact@v4` con `name:` explícito.
- `test` y `deploy` tienen `actions/download-artifact@v4` con el **mismo** `name`.
- Ninguna acción de artifact usa v1/v2/v3 (deprecadas).

## 4. Prerrequisitos

- `python3` con PyYAML.
- Haber hecho `activities/01-cache-python-deps` y leído `examples/02-artifact-between-jobs`.

**Costos**: ninguno (todo local).

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-starter.sh /tmp/share-build-artifact
cd /tmp/share-build-artifact
cat .github/workflows/pipeline.yml
```

Verás un único job `all-in-one` que hace build + test + deploy en secuencia.

### 5.2 Objetivo

Edita `/tmp/share-build-artifact/.github/workflows/pipeline.yml` hasta tener:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: |
          mkdir -p dist
          echo "version=$(git rev-parse --short HEAD 2>/dev/null || echo local)" > dist/VERSION
          echo "built at $(date -u +%FT%TZ)" > dist/app.txt
      - uses: actions/upload-artifact@v4
        with:
          name: app-dist
          path: dist/
          retention-days: 7
          if-no-files-found: error

  test:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: app-dist
          path: dist/
      - name: Verify bundle
        run: |
          test -s dist/app.txt
          test -s dist/VERSION

  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: app-dist
          path: dist/
      - name: Deploy
        run: echo "Deploying $(cat dist/VERSION)"
```

**Reglas**:
- El `name:` del artifact debe ser **el mismo** en el upload y los dos downloads.
- `deploy.needs` puede ser `test` (recomendado) o `[build, test]`.
- No puedes usar `actions/upload-artifact@v3` ni `@v2` ni `@v1` — todas deprecadas (sunset junio 2024).

### 5.3 Validar

```bash
bash tests/validate.sh /tmp/share-build-artifact
```

Debe terminar con `OK: actividad completada correctamente.`.

## 6. Resultado esperado

- Workflow con tres jobs: `build`, `test`, `deploy`.
- Cadena `needs:` correcta: `test` depende (directa o transitivamente) de `build`; `deploy` depende (directa o transitivamente) de `build`.
- Upload único en `build` con `actions/upload-artifact@v4` y `name` explícito.
- Download en `test` y `deploy` con `actions/download-artifact@v4` y **el mismo `name`**.
- Validator pasa.

## 7. Criterios de aceptación

- [ ] Funcionalidad: `validate.sh` pasa.
- [ ] Calidad: `retention-days` y `if-no-files-found: error` presentes en el upload.
- [ ] Seguridad: no usas versiones deprecadas de artifact actions.
- [ ] Comprensión: puedes explicar por qué `deploy` descarga el artifact en vez de rebuildear.

## 8. Validación

`tests/validate.sh` chequea con `python3 + PyYAML`:

1. YAML del workflow parsea.
2. Existen jobs `build`, `test`, `deploy`.
3. `test.needs` y `deploy.needs` encadenan (transitivamente) con `build`.
4. `build` tiene un step `uses: actions/upload-artifact@v4` con `name:`.
5. `test` y `deploy` tienen cada uno un step `uses: actions/download-artifact@v4` con `name:`.
6. Los tres `name`s coinciden.
7. Ningún step usa `@v1/@v2/@v3` de artifact actions.

## 9. Preguntas de reflexión

1. Si olvidas `needs: build` en `test`, ¿qué error esperas y en qué momento?
2. ¿Qué pasa si pones `actions/upload-artifact@v4` en `build` pero `actions/download-artifact@v3` en `test`? ¿Por qué?
3. ¿En qué escenario preferirías que `deploy` **reconstruya** el `dist/` en vez de descargarlo?
4. ¿Qué cambiarías para que `test` corra **en paralelo** con un `lint` que también necesita el bundle?
5. Si tu pipeline corre 50 veces al día y cada artifact son 200 MB con retención 90 días, ¿cuánto storage consumes al mes? ¿Qué política adoptarías?

## 10. Extensiones (opcional)

- **E1** — Añade un cuarto job `lint` que también consuma el artifact y corra en paralelo con `test`.
- **E2** — Convierte `build` en matriz `os: [ubuntu-latest, macos-latest]` subiendo `name: app-dist-${{ matrix.os }}` y haz que `deploy` descargue solo el de ubuntu con `pattern:`.
- **E3** — Añade `permissions: contents: read` a nivel workflow y verifica que nada se rompe.

## 11. Limpieza

```bash
rm -rf /tmp/share-build-artifact
```
