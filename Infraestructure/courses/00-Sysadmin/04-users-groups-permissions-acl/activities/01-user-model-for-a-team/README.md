# Actividad 01 — Modelo de usuarios para un equipo (arquitectura)

> **Tipo:** arquitectura (diseño + implementación).
> **Duración estimada:** 60 min.
> **Prerrequisitos:** haber leído la lección y reproducido el ejemplo 01.

## Contexto

Te acaban de contratar como sysadmin en una startup pequeña. Hay una única VM Linux (`srv01`) donde se despliega la app y donde el equipo hace trabajo compartido. Hasta hoy todo el mundo entraba como `root` por SSH (así, sin broma). Tu primer encargo: construir un modelo de acceso sano.

En `starter/team-spec.md` tienes la especificación del equipo y lo que cada rol debe poder hacer. Tu trabajo es:

1. **Diseñar** el modelo (en papel: qué grupos, qué usuarios, qué directorios, qué permisos).
2. **Aplicarlo** con un script idempotente.
3. **Validarlo** con el test automático.

## Qué entregas

Un script `solution/apply-users.sh` que, ejecutado como root en una VM limpia (o en una existente, es idempotente), deja el sistema con:

- Usuarios y grupos creados según la spec.
- Un directorio compartido `/srv/project` con setgid, pensado para `developers`.
- Un directorio `/srv/audit` sólo-lectura para el grupo `auditors`, escritura sólo para `root`.
- Shells y expiración de cuentas aplicados.

Puedes basarte en el solution de referencia **después** de intentarlo tú.

## Pasos sugeridos

1. Lee `starter/team-spec.md` entero.
2. En papel/notas, dibuja la tabla *usuario → grupos → directorios accesibles*.
3. Escribe el script en `solution/apply-users.sh` (puedes partir del solution de referencia o escribirlo de cero).
4. Ejecuta: `sudo bash solution/apply-users.sh`.
5. Valida: `sudo bash tests/validate.sh`.
6. Si falla, lee el mensaje y arregla el script. Repite hasta "OK".

## Criterio de éxito

El validador imprime `OK: todas las comprobaciones pasaron.` y los permisos sobreviven a crear archivos como usuarios distintos (ver el apartado "Pruebas manuales" al final del validador).

## Importante

- **VM descartable**: la actividad crea usuarios y directorios reales. No lo pruebes en tu equipo personal.
- Si fallas y el sistema queda a medias, el script es idempotente: ejecútalo de nuevo.
- Limpieza al terminar:

```bash
sudo userdel -r ana  2>/dev/null || true
sudo userdel -r diego 2>/dev/null || true
sudo userdel -r sofia 2>/dev/null || true
sudo userdel -r audit1 2>/dev/null || true
sudo groupdel developers 2>/dev/null || true
sudo groupdel auditors 2>/dev/null || true
sudo rm -rf /srv/project /srv/audit
```
