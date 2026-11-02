# Ejemplo 01 — Unidad de servicio mínima

Un `.service` funcional en el menor número de líneas posible, con `[Install]`, `Restart=on-failure`, y logs al journal. Es el esqueleto sobre el que crecen todas las unidades reales.

## Archivos

- `files/hello.service` — unidad.
- `files/install.sh` — instala, habilita y arranca; muestra logs.

## Qué observar

1. **Dónde se instala**: `/etc/systemd/system/hello.service` (zona del admin, no `/lib/...`).
2. **Qué hace `daemon-reload`**: releer unidades sin reiniciar servicios.
3. **Qué hace `enable`**: crea el symlink desde `multi-user.target.wants/`.
4. **Qué hace `start`**: lanza el proceso ya.
5. **Dónde van los logs**: `journalctl -u hello` — stdout del proceso.
6. **Qué pasa si matas el proceso**: `sudo pkill -f 'bash.*hello'` → vuelve solo (Restart=on-failure).

## Ejecutar

```bash
sudo bash files/install.sh
systemctl status hello.service
journalctl -u hello.service -f
```

## Limpiar

```bash
sudo systemctl disable --now hello.service
sudo rm /etc/systemd/system/hello.service
sudo systemctl daemon-reload
```
