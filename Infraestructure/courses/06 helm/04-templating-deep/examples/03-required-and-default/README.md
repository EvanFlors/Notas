# Ejemplo 03 — `required` y `default`: contratos sin sorpresas

## Concepto que demuestra

Cómo definir el "contrato" de un chart con las dos funciones complementarias:

- `required "msg" .Values.x` — **aborta el render** si falta, con mensaje accionable.
- `.Values.x | default <algo>` — **cae a un valor sano** si falta.

Elegir entre una y otra es decidir si un value es parte del contrato público (obligatorio) o un detalle con un default razonable.

## Contexto

Chart mínimo con tres values:

- `image.repository` → **obligatorio**. Sin este value el chart no tiene sentido.
- `image.tag` → **con default `"latest"`**. Lo "razonable" aquí sería desactivable; en producción conviene que falle sin tag explícito, pero el ejemplo busca mostrar el patrón.
- `replicas` → **con default `1`**. 90% de los casos quieren 1 réplica, no vale la pena hacerla obligatoria.

## Prerrequisitos

- Helm 3+.

## Ejecución

```bash
cp -r files /tmp/required-and-default
cd /tmp/required-and-default

# 1. Render con image.repository omitido  → debe fallar
helm template demo . --set image.repository=null
#   Error: execution error at (required-and-default/templates/deployment.yaml:...):
#     image.repository es obligatorio: define image.repository en values.yaml o --set

# 2. Render completo (valores por default aplican)
helm template demo . --set image.repository=myapp
# → image: "myapp:latest", replicas: 1

# 3. Override explicito
helm template demo . --set image.repository=myapp,image.tag=v2.0,replicas=3
```

## Resultado esperado

- Sin `image.repository` → render falla con mensaje claro.
- Con solo `image.repository=myapp` → render exitoso: tag `latest`, replicas `1`.
- Con todo override → valores propagan correctamente.

## Interpretación

- `required` es la **única** forma correcta de hacer un value obligatorio. Alternativas (comprobar con `if`, levantar `fail`) existen pero `required` es el idiom reconocido por lectores humanos y por tooling (p. ej. `helm-docs`).
- `default` protege contra typos y omisiones comunes, pero cuidado con valores "falsy válidos": `0`, `""`, `false`, listas vacías. En esos casos, `default` siempre cae al fallback aunque el usuario *haya* puesto el value legítimamente.
- El mensaje de `required` lo leen humanos bajo presión. Decirles **qué value falta y dónde ponerlo** es mejor que `"missing"`.

## Errores frecuentes

- Usar `required` sin mensaje → mensaje por defecto críptico.
- Usar `default` cuando debería ser `required` → el usuario descubre el problema en el cluster, no al render.
- `.Values.x | required "msg"` **es inválido** — el orden es `required "msg" .Values.x`. Memorizarlo: el mensaje va primero.

## Limpieza

```bash
rm -rf /tmp/required-and-default
```
