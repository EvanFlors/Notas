# Ejemplo 02 — Drop-in override

Modificar una unidad del sistema sin editar el archivo original (que sería sobre-escrito por el próximo update del paquete).

## El problema

El paquete `nginx` instala `/lib/systemd/system/nginx.service` con `LimitNOFILE=1024`. Tu carga de trabajo real necesita 65536. Editar ese archivo es incorrecto: el próximo `apt upgrade` lo revierte.

## La solución: drop-in

Crea un directorio con el nombre de la unidad seguido de `.d/` dentro de `/etc/systemd/system/`, y pon ahí uno o más archivos `.conf`. Systemd fusiona todos los drop-ins con la unidad base.

### Camino manual

```bash
sudo mkdir -p /etc/systemd/system/nginx.service.d
sudo tee /etc/systemd/system/nginx.service.d/override.conf <<'EOF'
[Service]
LimitNOFILE=65536
Environment=NGINX_WORKERS=8
EOF
sudo systemctl daemon-reload
sudo systemctl restart nginx.service
```

### Camino asistido

```bash
sudo systemctl edit nginx.service
```

Abre `$EDITOR` con un archivo vacío ya ubicado en el drop-in correcto. Al guardar, hace `daemon-reload` solo.

Para editar el archivo completo (crea copia en `/etc/systemd/system/`, no es drop-in):

```bash
sudo systemctl edit --full nginx.service
```

Pero esto rompe el *update path* del paquete; prefiere drop-ins salvo que cambies tanto que el archivo deje de parecer el original.

## Verificar

```bash
systemctl cat nginx.service
```

Muestra el archivo base primero, luego cada drop-in con un comentario `# /etc/systemd/system/nginx.service.d/override.conf`. Si no aparece tu override: olvidaste `daemon-reload`, o el nombre del directorio no coincide con el nombre exacto de la unidad.

```bash
systemctl show nginx.service -p LimitNOFILE
```

Muestra el valor efectivo (lo que systemd realmente aplicará). Si tu drop-in no tomó efecto, aquí lo ves.

## Reglas de fusión

- **Última ocurrencia gana** para valores escalares (p.ej. `Restart=`).
- **Listas se concatenan** por default. Para resetear una lista, usa el valor vacío: `Environment=` en una línea sola (con `=` y nada después) borra las anteriores.
- Dentro de `*.service.d/`, los archivos se leen en orden alfabético. Nombra tus overrides con prefijo numérico si el orden importa: `10-limits.conf`, `20-env.conf`.

## Cuándo NO usar drop-in

- Si estás escribiendo tu propia unidad desde cero, pon todo en `/etc/systemd/system/tu-app.service` y punto.
- Si vas a cambiar `ExecStart=`, nota que para resetearlo necesitas `ExecStart=` vacío *antes* de la nueva línea:

  ```ini
  [Service]
  ExecStart=
  ExecStart=/usr/local/bin/nginx -g 'daemon off;'
  ```
