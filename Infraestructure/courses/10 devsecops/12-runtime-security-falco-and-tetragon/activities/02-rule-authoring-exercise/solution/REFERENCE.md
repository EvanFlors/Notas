# REFERENCE — sec-12-02-rule-authoring-exercise

> Modelo. No es la única respuesta correcta.

## Seccion A — Regla propuesta

```yaml
- macro: var_log_path
  condition: evt.arg.filename startswith "/var/log" or fd.name startswith "/var/log"

- macro: world_writable_mode
  condition: >
    (evt.arg.mode contains "7" and evt.arg.mode endswith "7")
    or evt.arg.mode in ("0666", "0777")

- rule: World writable file under var log
  desc: >
    Un proceso en un contenedor fijo permisos world-writable (o+w) sobre un
    fichero bajo /var/log. Patron de tampering de logs o dropper diferido.
  condition: >
    evt.type in (chmod, fchmod, fchmodat)
    and container
    and var_log_path
    and world_writable_mode
    and not proc.name in (fluent-bit, fluentd, vector, logrotate)
  output: >
    Permisos world-writable aplicados bajo /var/log
    (user=%user.name container=%container.name image=%container.image.repository
     proc=%proc.name cmdline=%proc.cmdline file=%evt.arg.filename mode=%evt.arg.mode)
  priority: WARNING
  tags: [container, filesystem, tampering, mitre_defense_evasion, T1222]
  source: syscall
```

Decisiones:

- **condition**: capturamos los tres syscalls que cambian modo (`chmod`, `fchmod`, `fchmodat`); evitamos atar la regla a `proc.name=chmod` porque `install`, `cp -p`, `tar -xp` también acaban llamando a esos syscalls. Excluimos agentes de logs legítimos.
- **output**: incluye los campos para que un humano decida en segundos: quién, dónde, con qué modo, qué comando.
- **priority: WARNING**: amerita acción pero no interrumpe (no es `CRITICAL`); un `NOTICE` quedaría sepultado.
- **tags**: `T1222` (File and Directory Permissions Modification) es el MITRE correcto.

## Seccion B — Falsos positivos

1. **Agentes de logs legítimos** (`fluent-bit`, `fluentd`, `vector`, `logrotate`) que ocasionalmente ajustan permisos. Suprimido con la lista `not proc.name in (...)`. En producción esto se escribiría como `exceptions` nombradas para que el mantenimiento sea más legible.
2. **Init containers que preparan `/var/log/<app>` con `install -m 0777`.** Suprimido con una exception que whiteliste por `container.image.repository = acme/log-init` y la primera ejecución tras arranque (`container.start_ts` reciente). Alternativa: cambiar el init container para usar `0775` + GID de grupo compartido.

## Seccion C — Falsos negativos

1. **El atacante usa `setfacl -m o+w`** (ACL en vez de `chmod`). La regla no dispara. Mitigación: regla hermana que capture `execve` de `setfacl` con argumentos permisivos (`-m o+w`), o `evt.type in (setxattr, fsetxattr)` filtrando por `system.posix_acl_access`.
2. **El atacante escribe un fichero con `umask 0` + `open(O_CREAT, 0666)` desde el inicio.** No hay `chmod` posterior. Mitigación: regla hermana sobre `open` con `evt.arg.mode in ("0666","0777")` bajo `/var/log`. Esto genera más ruido, pero captura el patrón "nacido abierto".

## Seccion D — Decision: detect vs enforce

- **Recomendación: detect** (Falco), al menos las primeras N semanas.
- **Justificación:** aunque "world-writable bajo `/var/log`" es poco frecuente, no es imposible en entornos legacy o con agentes mal configurados. Pasar a enforce de día uno corre riesgo real de matar un init container legítimo. Falco detecta → canal `#sec-runtime` con rotación on-call → humano decide.
- **Si enforce** (una vez verificado 2–4 semanas sin FP): TracingPolicy de **Tetragon** sobre `kprobe` de `chmod_common` o `security_inode_setattr` con selectores por `path startswith /var/log` + `mode & 0002 != 0` y `matchActions: Sigkill`. Preferible `kprobe` LSM (`security_*`) frente a `syscall` directo porque el LSM corre **antes** de aplicar el cambio y además captura todas las vías (incluido `setfacl` mediante hooks adyacentes).
- **Output elegido:** Falcosidekick → Slack `#sec-runtime` (prioridad `WARNING`), y mirror a Loki para búsqueda histórica. Correlación periódica con audit log del API server para encontrar quién creó el Pod que generó la alerta.
