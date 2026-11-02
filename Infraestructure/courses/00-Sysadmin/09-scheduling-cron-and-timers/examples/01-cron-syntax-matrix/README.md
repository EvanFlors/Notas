# Ejemplo 01 — Matriz de sintaxis cron

Diez patrones de 5 campos reales, lo que **significan**, y la trampa típica asociada. Léelos sin consultar la lección y verifica tu modelo mental.

Formato: `m h dom mon dow` seguido del comando (omitido aquí para enfocarse en el calendario).

| # | Expresión | Significado | Nota / trampa |
|---|-----------|-------------|---------------|
| 1 | `* * * * *` | Cada minuto, siempre. | Útil para probar que cron está vivo; perjudicial para cualquier otra cosa. |
| 2 | `*/5 * * * *` | Cada 5 minutos (00, 05, 10, 15, …). | `/5` cuenta desde el inicio del rango (0). No es "cada 5 min desde ahora". |
| 3 | `0 * * * *` | En el minuto 0 de cada hora (equivale a `@hourly`). | Si N jobs usan esto, pico de carga sincronizado a cada hora exacta. Añade jitter con `sleep $((RANDOM % 60))` o cambia a un minuto distinto por job. |
| 4 | `0 3 * * *` | Todos los días a las 03:00 (equivale a `@daily` pero a las 03 en vez de 00). | Si el host está apagado a esa hora, se pierde. `anacron` o `Persistent=true` resuelven. |
| 5 | `*/15 9-17 * * 1-5` | Cada 15 minutos, entre 09:00 y 17:45, de lunes a viernes. | `9-17` incluye la hora 17 completa (hasta 17:59), no se corta en 17:00. |
| 6 | `0 0 1 * *` | Minuto 0, hora 0, día 1 de cada mes (equivale a `@monthly`). | Febrero sigue teniendo día 1; no hay sorpresa, pero sí la hay con día 31. |
| 7 | `0 0 31 * *` | Hora 00:00 del día 31 — solo los meses con 31 días. | Para "último día del mes" cron **no tiene operador**. Alternativa: `0 0 28-31 * *` + `test $(date -d tomorrow +%d) -eq 1` en el script. |
| 8 | `0 2 * * 1` | 02:00 cada lunes. | `1` = lunes (ISO). `0` o `7` = domingo (ambos aceptados). |
| 9 | `0 0 1 * 1` | 00:00 del día 1 del mes **O** cada lunes. | Trampa clásica: cuando `dom` y `dow` **ambos** son no-`*`, cron hace **OR**, no AND. |
| 10 | `@reboot` | Una vez, cuando el daemon de cron arranca. | No es "al login" ni "al bootear el kernel", es "cuando `cron`/`crond` arranca". En sistemas con systemd timers, prefiere `OnBootSec=` por observabilidad. |

## Cómo verificar cualquier expresión

Para cron no hay un parser oficial fuera del propio daemon, pero puedes:

```bash
# Imprime el PATH que ve cron (deja esta línea 2 min, luego borra)
* * * * * env > /tmp/cron-env.txt
```

Para systemd timers (expresión `OnCalendar=`), sí hay un parser:

```bash
systemd-analyze calendar "Mon..Fri *-*-* 09:00"
systemd-analyze calendar "*-*-* 03:00:00" --iterations=5
```

Muestra las próximas N ejecuciones. **Usa esto antes de instalar cualquier timer no trivial.**

## Ejercicio

Escribe en papel la expresión cron (o `OnCalendar=`) para:

1. Cada 10 minutos solo entre las 08:00 y las 20:00, cualquier día.
2. Primer día de cada trimestre a las 06:00.
3. Cada hora en punto, excepto de 00:00 a 05:00.
4. Cada sábado a las 23:00, pero solo en los meses impares.
5. Dos veces al día: 06:30 y 18:30.

(Luego verifica con `systemd-analyze calendar` las versiones de timer.)
