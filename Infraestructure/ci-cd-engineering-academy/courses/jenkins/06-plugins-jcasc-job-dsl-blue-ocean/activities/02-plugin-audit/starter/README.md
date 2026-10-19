# Starter — jk-06-02

El fichero `plugins-current-raw.txt` contiene un volcado hipotético de un Jenkins legacy con 24 plugins instalados sin pinning. Úsalo como punto de partida.

```bash
mkdir -p /tmp/jk-06-02
cp plugins-current-raw.txt /tmp/jk-06-02/plugins-current.txt
cd /tmp/jk-06-02
touch plugins-target.txt plugin-audit.md
```

Puedes modificar `plugins-current.txt` si quieres añadir o quitar algún plugin para tu análisis — el validador solo exige que `plugins-target.txt` tenga **menos** líneas que `plugins-current.txt`.
