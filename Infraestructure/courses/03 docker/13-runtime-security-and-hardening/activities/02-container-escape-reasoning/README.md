# Actividad 02 — Razonamiento sobre vectores de escape

## 1. Identificación

- **ID:** `dkr-13-02-container-escape-reasoning`
- **Tecnología:** `docker`
- **Módulo:** `13-runtime-security-and-hardening`
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** independent

## 2. Contexto

El hardening es útil sólo si entiendes **de qué estás protegiéndote**. En esta actividad produces un documento `ANALYSIS.md` explicando, con tus propias palabras, los vectores comunes de escape de contenedor: cómo funcionan, cómo los detectas en un `docker inspect` o `docker run`, y qué mitigación concreta aplicas.

No se ejecuta ningún ataque: es un ejercicio de razonamiento y escritura. El validador comprueba la **estructura** y la **cobertura** del documento, no la prosa.

## 3. Objetivos

Al terminar, tu `ANALYSIS.md` cubre al menos **cuatro** de los siguientes seis vectores, y cada vector tiene las cuatro subsecciones exigidas:

- `V1 — docker.sock montado en el contenedor`
- `V2 — --privileged`
- `V3 — CAP_SYS_ADMIN (sin --privileged)`
- `V4 — Montar / del host (o /etc, /root, /var/run)`
- `V5 — --network host`
- `V6 — Kernel exploit via syscall no filtrado (seccomp unconfined)`

Por cada vector, cuatro subsecciones obligatorias con sus headings:

```markdown
### V1 — Docker socket montado

**Mecanismo**: (3-6 líneas explicando por qué funciona)

**Detección**: (cómo lo reconoces en `docker inspect` o en un `docker run`)

**Impacto**: (hasta dónde escala el atacante)

**Mitigación**: (qué quitas o cambias, con el flag concreto)
```

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` completo, especialmente §§5, 6, 8, 11.
- Haber visto el `examples/03-why-not-mount-docker-sock/`.
- No se requiere Docker para esta actividad (es escritura), aunque es útil para probar hipótesis.

## 5. Instrucciones

### 5.1 Bootstrap

```bash
bash courses/docker/13-runtime-security-and-hardening/activities/02-container-escape-reasoning/starter/bootstrap.sh /tmp/dkr13-02
```

Esto crea `/tmp/dkr13-02/work/ANALYSIS.md` con el esqueleto marcado como `TODO`.

### 5.2 Escribe

Abre `/tmp/dkr13-02/work/ANALYSIS.md` y rellena al menos **cuatro** de los seis vectores, respetando los cuatro headings fijos por vector (`**Mecanismo**`, `**Detección**`, `**Impacto**`, `**Mitigación**`).

Reglas:

- Español. 3-8 líneas por subsección. Prosa, no bullets largos.
- Precisión técnica: nombra las capabilities, los flags, las rutas exactas.
- No copies la lección literal. Reescribe con tus palabras.
- Para la mitigación: no digas "no lo hagas". Di qué flag/cambio concreto aplicas y qué alternativa existe para el caso de uso legítimo (si lo hay).

### 5.3 Valida

```bash
bash courses/docker/13-runtime-security-and-hardening/activities/02-container-escape-reasoning/tests/validate.sh /tmp/dkr13-02
```

El validador exige:

- `ANALYSIS.md` existe en `/tmp/dkr13-02/work/`.
- Al menos cuatro de los seis headings `### V<N>` presentes.
- Cada vector tiene las cuatro subsecciones (`**Mecanismo**`, `**Detección**`, `**Impacto**`, `**Mitigación**`).
- Cada subsección tiene al menos 2 líneas no vacías (desalienta "TODO").
- Longitud total >= 50 líneas no vacías.
- No contiene el token `TODO:` ni `<rellena>` ni placeholders del esqueleto.

## 6. Resultado esperado

- `/tmp/dkr13-02/work/ANALYSIS.md` cumple todos los checks estructurales.
- Puedes defender verbalmente cada mitigación.

## 7. Criterios de aceptación

- [ ] ≥4 vectores cubiertos con sus 4 subsecciones.
- [ ] Longitud razonable (>=50 líneas no vacías).
- [ ] Sin placeholders (`TODO`, `<rellena>`, etc.).
- [ ] Mitigación concreta (flag o cambio arquitectónico), no genérica.

## 8. Validación

```bash
bash courses/docker/13-runtime-security-and-hardening/activities/02-container-escape-reasoning/tests/validate.sh /tmp/dkr13-02
```

## 9. Preguntas de reflexión

1. De los seis vectores, ¿cuáles persisten si corres rootless Docker? ¿Cuál es el delta real?
2. Si tu CI runner **tiene que** construir imágenes, ¿qué alternativa das al socket mount? Explica trade-offs.
3. ¿Por qué `--network host` es un problema de seguridad y no sólo de aislamiento?
4. En un escape por `CAP_SYS_ADMIN`, ¿qué habrías visto en `docker inspect` *antes* del incidente?
5. ¿Cuál de estos vectores detectaría un escáner como Trivy, y cuál NO?

## 10. Extensiones

- **E1** — Para cada vector, añade una referencia a un CVE real o POC público (sin ejecutarlo).
- **E2** — Convierte tu análisis en una checklist de 10 ítems para code review de PodSpecs de Kubernetes.
- **E3** — Compara los seis vectores con los controles de **PodSecurityStandards baseline/restricted** de Kubernetes: ¿cuál control cubre cuál?

## 11. Limpieza

```bash
rm -rf /tmp/dkr13-02
```
