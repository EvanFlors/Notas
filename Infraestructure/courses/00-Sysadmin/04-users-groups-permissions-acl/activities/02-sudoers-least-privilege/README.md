# Actividad 02 — sudoers de mínimo privilegio (debug)

> **Tipo:** debug + hardening.
> **Duración estimada:** 45 min.
> **Prerrequisitos:** haber leído la lección y reproducido el ejemplo 02.

## Contexto

Te llega una página de soporte: "el equipo `webops` ya no puede reiniciar nginx desde ayer, nos sale `sorry, user ... is not allowed`". Investigas y encuentras en el servidor el archivo `/etc/sudoers.d/50-webops` que un compañero bienintencionado editó con `vim` en vez de `visudo`. Está en `starter/broken-sudoers`.

Tu trabajo:

1. **Diagnosticar** por qué `visudo -cf starter/broken-sudoers` falla.
2. **Corregir** la sintaxis.
3. Mientras lo haces, **endurecer** la regla para que respete el principio de mínimo privilegio: `webops` debe poder operar `nginx` y **sólo** `nginx`, nada más.
4. Guardar el resultado en `solution/fixed-sudoers`.

## Qué está mal en el starter

Hay al menos los siguientes problemas (algunos de sintaxis que `visudo -cf` detecta, otros de política que no):

- Al menos un error de sintaxis que `visudo` rechaza.
- Rutas no absolutas en algún comando.
- Comandos excesivos (p. ej. `systemctl` sin acotar: permitiría `systemctl poweroff`).
- Un `NOPASSWD: ALL` que da shell efectivo de root.
- Un alias mal declarado.

Encuentra todo lo que haya y corrige. El validador comprueba tanto sintaxis como política.

## Cómo trabajar

```bash
# 1. Reproducir el error de sintaxis
visudo -cf starter/broken-sudoers

# 2. Copiar como punto de partida
cp starter/broken-sudoers solution/fixed-sudoers

# 3. Editar con visudo (recomendado) o con tu editor + visudo -cf
sudo visudo -cf solution/fixed-sudoers

# 4. Validar
bash tests/validate.sh
```

## Qué debe cumplir `solution/fixed-sudoers`

- `visudo -cf solution/fixed-sudoers` termina con `parsed OK` (exit 0).
- Define al menos un `Cmnd_Alias` cuyo nombre contenga `NGINX` (en mayúsculas, como suele estilizarse).
- Concede a `%webops` sólo ese alias (no `ALL`, no `/usr/bin/systemctl` abierto).
- No debe aparecer `NOPASSWD: ALL`.
- Rutas absolutas en todos los comandos.
- Nada autoriza `systemctl poweroff`, `systemctl reboot`, `bash`, `sh`, `vi`, `vim`, `less` ni `/bin/*` genérico.

## Criterio de éxito

El validador imprime `OK: fixed-sudoers pasa sintaxis y política.`.

## Pista

El error de sintaxis típico de `visudo` es "parse error ... near line N". Lee el número de línea literal: a veces el error real está en la línea anterior (una continuación `\` olvidada o un `=` en lugar de `:`).
