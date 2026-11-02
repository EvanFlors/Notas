# Ejemplo 02 — Tour por contextos SELinux

Este ejemplo es un paseo guiado por los tres sitios donde SELinux "aparece" en el día a día: ficheros, procesos y puertos. Nada que ejecutes aquí modifica el sistema.

Requiere una máquina con SELinux instalado (RHEL, Fedora, Rocky, Alma, CentOS Stream). En Ubuntu sustituye por AppArmor: `aa-status`.

## 1. Modo actual

```bash
getenforce
```

Posibles salidas: `Enforcing`, `Permissive`, `Disabled`. Para este tour vale cualquiera; para las actividades necesitas `Enforcing`.

## 2. Contextos de ficheros

```bash
ls -Z /etc | head -20
```

Verás algo así:

```
system_u:object_r:etc_t:s0            adjtime
system_u:object_r:net_conf_t:s0       hostname
system_u:object_r:passwd_file_t:s0    passwd
system_u:object_r:shadow_t:s0         shadow
system_u:object_r:ssh_home_t:s0       ssh/
```

Observa:

- `shadow_t` sólo puede leerlo un proceso en un dominio autorizado (como `passwd`, en `passwd_t`). Ni `cat` corriendo como `root` desde una shell `unconfined_t` lo lee en permissive si cambias el tipo erróneamente.
- `net_conf_t` es la etiqueta "configuración de red": `NetworkManager` puede escribir ahí, un demonio web no.

## 3. Contextos de procesos

```bash
ps -eZ | head
```

Salida típica:

```
system_u:system_r:init_t:s0          1 ?        00:00:03 systemd
system_u:system_r:kernel_t:s0        2 ?        00:00:00 kthreadd
system_u:system_r:sshd_t:s0        912 ?        00:00:00 sshd
unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 2334 pts/0 00:00:00 bash
```

Observa:

- `sshd_t` es el dominio del demonio SSH. SELinux restringe qué puede hacer un proceso ahí.
- Tu shell interactiva suele estar en `unconfined_t` (política targeted): sin restricciones MAC. Por eso parece "que SELinux no hace nada" cuando lo pruebas desde tu terminal.

Filtra un servicio concreto:

```bash
ps -eZ | grep -E 'nginx|httpd' || echo "(sin instancias)"
```

## 4. Contextos de sockets

```bash
sudo ss -ltnpZ | head
```

Verás los puertos escuchando con el contexto del proceso que los abrió. Útil cuando sospechas que un servicio corre bajo el dominio equivocado.

## 5. Puertos etiquetados

```bash
sudo semanage port -l | head -20
```

Ejemplo relevante:

```
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
ssh_port_t                     tcp      22
```

`http_port_t` ya incluye 8443 en RHEL 9 por defecto. Pero en versiones donde no está, un `nginx` escuchando en 8443 falla con `bind: Permission denied` aunque el firewall lo permita. Esa es la base de la actividad 2.

Filtra por tipo:

```bash
sudo semanage port -l | grep http_port_t
```

## 6. Booleans

```bash
getsebool -a | head -20
sudo semanage boolean -l | grep httpd
```

Ejemplos típicos:

- `httpd_can_network_connect` — permite al web server hacer conexiones salientes (necesario si actúa como proxy).
- `httpd_enable_cgi` — habilita CGI.
- `nis_enabled` — permite consultas NIS, suele ser necesario en entornos legacy.

## 7. Ver denials recientes

```bash
sudo ausearch -m AVC -ts recent | head -30
```

Si no hay denials, no verás nada: eso es buena señal. Si estás diagnosticando un problema, aquí es donde vive la evidencia.

## Qué llevarte

- `ls -Z`, `ps -eZ`, `ss -ltnpZ`: añadir `-Z` muestra el contexto SELinux en herramientas estándar.
- `semanage port -l`: catálogo de puertos etiquetados.
- `getsebool -a` / `semanage boolean -l`: catálogo de interruptores de política.
- `ausearch -m AVC`: el único lugar donde buscar al diagnosticar.
