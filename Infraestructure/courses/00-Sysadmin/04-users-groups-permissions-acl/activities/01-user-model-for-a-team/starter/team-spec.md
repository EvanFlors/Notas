# Especificación del equipo — srv01

## Personas y rol

| Login   | Nombre     | Rol        | Notas                              |
|---------|------------|------------|------------------------------------|
| ana     | Ana López  | Developer  | Lead.                              |
| diego   | Diego Ruiz | Developer  |                                    |
| sofia   | Sofía Paz  | Developer  | Contratada 3 meses (becaria).      |
| audit1  | Auditor Ext| Auditor    | Externo. Sólo lectura de registros.|

## Grupos requeridos

- `developers` — todos los developers.
- `auditors` — todos los auditores externos.

## Shells y expiración

- Developers: shell `/bin/bash`, cambio de contraseña obligatorio cada **90 días**, aviso **7 días** antes.
- `sofia`: además, cuenta expira en **90 días** desde hoy (es becaria con contrato fijo).
- Auditores: shell `/bin/bash` también, misma política de 90/7.

## Directorios

### `/srv/project`

- Trabajo colaborativo de developers.
- Dueño: `root`, grupo: `developers`.
- Permisos: `drwxrws---` (modo `2770`, con setgid).
- Default ACL: archivos nuevos deben quedar legibles y escribibles por `developers`, sin acceso para `other`.
- Los auditores (`auditors`) deben poder **listar y leer** (no escribir) → añadir entrada ACL `g:auditors:rx` tanto en el directorio como en la default ACL.

### `/srv/audit`

- Dueño: `root`, grupo: `auditors`.
- Permisos: `drwxr-s---` (modo `2750`): `root` escribe, `auditors` leen/listan, `other` nada.
- Default ACL: archivos nuevos deben quedar `r--` para el grupo `auditors`.

## Restricciones

- Nadie recibe acceso `sudo` en esta actividad (eso es la siguiente).
- Las contraseñas iniciales no se piden: usa `passwd -d <user>` (sin contraseña) o déjalas bloqueadas; en una VM descartable es aceptable. El validador no inspecciona hashes.
- El script debe ser **idempotente**: ejecutarlo dos veces no debe romper nada ni cambiar permisos existentes correctos.
