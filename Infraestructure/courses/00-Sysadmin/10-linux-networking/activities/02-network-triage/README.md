# Actividad 02 — Triage de red por capas

## 1. Identificación

- **ID:** `sys-10-02-network-triage`
- **Tecnología:** `sysadmin`
- **Módulo:** `sys-10-linux-networking`
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** debug

## 2. Contexto

Un usuario reporta "no funciona X". Tu primera reacción no debe ser abrir `tcpdump`: debe ser **clasificar el fallo en una capa** y usar la herramienta mínima que la confirme. Esta actividad te presenta tres síntomas típicos y te pide identificar la capa, el comando que lo demuestra y la causa raíz.

Es `debug` porque no hay "configurar algo"; hay **razonar** sobre un síntoma dado.

## 3. Objetivos

Al terminar deberías poder:

- Diferenciar en segundos: fallo DNS vs fallo de ruta vs fallo TLS vs fallo de aplicación.
- Elegir, por cada capa, la herramienta de confirmación correcta.
- Documentar la causa raíz y el comando que la probó.

## 4. Prerrequisitos

- `curl`, `dig` (`bind-utils`/`dnsutils`), `ss`, `openssl` instalados.
- Red funcionando (**esta actividad no modifica red**; es puramente analítica).

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Lee el escenario

```bash
cd /path/to/activities/02-network-triage
cat starter/scenario.md
```

### 5.2 Resuelve cada caso

Para cada uno de los tres casos:

1. **Observa el síntoma** que `scenario.md` describe (incluye salida literal del comando que falló).
2. **Clasifica la capa**: DNS, L3 (ruta), L4 (puerto/filtro), L6 (TLS), L7 (app).
3. **Ejecuta un comando** que confirme tu hipótesis.
4. **Anota** en `starter/answers.md` (plantilla incluida) tres campos:
   - `layer:` — una de `dns`, `route`, `tls`.
   - `probe:` — el comando que usaste para confirmar.
   - `root_cause:` — frase corta en castellano.

### 5.3 Formato esperado

`starter/answers.md` ya trae la plantilla:

```markdown
## case1
layer: dns
probe: dig +short ejemplo.invalid @1.1.1.1
root_cause: dominio inexistente (NXDOMAIN).

## case2
layer: route
probe: ip route get 10.255.0.1
root_cause: no hay ruta hacia la subred destino.

## case3
layer: tls
probe: openssl s_client -connect expired.badssl.com:443 -servername expired.badssl.com
root_cause: certificado expirado.
```

(Los valores de arriba son solo ilustrativos; tu `scenario.md` fija los casos reales.)

### 5.4 Validar

```bash
bash tests/validate.sh
```

El script lee `starter/answers.md` y valida que `layer` sea el esperado para cada caso. No valida literal el comando `probe` ni el `root_cause` (lee la sección 10 — "Validación").

## 6. Resultado esperado

- `starter/answers.md` con las tres capas correctas.
- `tests/validate.sh` imprime `OK: actividad completada correctamente`.
- Puedes explicar sin consultar por qué una capa fue la correcta y no otra.

## 7. Criterios de aceptación

- [ ] Clasificación correcta de las tres capas.
- [ ] `probe` razonable (comando real que confirma la hipótesis).
- [ ] `root_cause` en una frase (no un ensayo).
- [ ] `tests/validate.sh` pasa.

## 8. Pistas (si estás atascado)

- **Caso 1** — un `curl` falla con `Could not resolve host`. ¿Qué capa trata de resolver nombres? ¿Qué pasa si cambias el resolver con `@…`?
- **Caso 2** — un `curl` cuelga hasta tiempo máximo y nunca ves bytes. `ping` tampoco llega. Mira `ip route get <ip_destino>`.
- **Caso 3** — un `curl` dice `SSL certificate problem`. ¿Qué herramienta te muestra el cert sin pasar por `curl`?

## 9. Preguntas de reflexión

1. ¿Por qué `dig +short NAME @1.1.1.1` es más diagnóstico que `nslookup NAME`?
2. En el **caso 2**, ¿por qué `ping` también falla y no solo `curl`? ¿Qué capa comparten?
3. En el **caso 3**, ¿la aplicación servidora está "bien" o "mal"? ¿La respuesta cambia según quién sea el cliente?
4. Si en lugar de "timeout" ves "connection refused", ¿cambiaría tu clasificación de capa? ¿Qué herramienta usarías entonces?
5. ¿Cuándo tiene sentido subir a `tcpdump` en vez de resolver con los cuatro de arriba (`dig`, `ip`, `ss`, `curl -v`)?

## 10. Validación

```bash
bash tests/validate.sh
```

Chequea literalmente los valores de `layer:` para `case1`, `case2`, `case3` en `starter/answers.md`.

## 11. Solución de referencia

Ver `solution/triage.md`. Lee **solo después** de resolver.
