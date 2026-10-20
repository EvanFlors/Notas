# Solución de referencia — Extraer role `webserver`

## Estructura final

```
/tmp/ans-04-extract/
├── site.yml
└── roles/
    └── webserver/
        ├── README.md
        ├── defaults/main.yml
        ├── vars/main.yml
        ├── tasks/
        │   ├── main.yml
        │   ├── install.yml
        │   ├── configure.yml
        │   └── service.yml
        ├── handlers/main.yml
        ├── templates/nginx.conf.j2
        └── meta/main.yml
```

Los archivos de esta carpeta `solution/` son la referencia. Copia la estructura (no tal cual, para fijar el aprendizaje) y adapta.

## Decisiones clave

1. **`defaults/main.yml`** contiene todo lo que el consumidor espera poder cambiar: `webserver_port`, `webserver_server_name`, `webserver_worker_processes`, `webserver_worker_connections`, `webserver_user`.
2. **`vars/main.yml`** contiene lo interno: `webserver_pkg`, `webserver_service`, `webserver_conf_path`. Si alguien los sobreescribe desde `group_vars`, probablemente rompa el role.
3. **`tasks/main.yml`** no implementa — sólo `import_tasks:` las fases, con tags por fase. Esto permite `--tags configure` desde fuera (`import_role` propaga tags).
4. **`handlers/main.yml`** expone `reload nginx` y `restart nginx`. Preferimos `reload` para cambios de config (no interrumpe conexiones).
5. **`meta/main.yml`** lista Ubuntu, Debian y RHEL. `dependencies: []` — este role es autónomo.
6. **README** cubre: qué hace, variables (requeridas y opcionales), OS, ejemplo de uso.

## Autoevaluación

- ¿Tu `defaults/main.yml` tiene variables de implementación (paquete, path)? Si sí, muévelas a `vars/`.
- ¿Tu `tasks/main.yml` tiene lógica inline? Si sí, muévela a `install.yml`, `configure.yml` o `service.yml`.
- ¿Tu template usa variables sin prefijo (`port` en lugar de `webserver_port`)? Peligro de colisión con otros roles.
- ¿Tu README cita las variables de `vars/`? **No debería** — son privadas.

## Qué viene

- `ans-05` — meter el role en una collection con namespace propio.
- `ans-08` — Molecule para probar el role en Docker contra 3 distros.
