# Módulo 01 — Fundamentos de Electrónica Digital

## Propósito

Establecer las bases físicas y lógicas sobre las que se construye toda computadora: desde las magnitudes eléctricas que gobiernan los circuitos hasta la representación binaria de datos y los circuitos secuenciales que habilitan el almacenamiento de estado.

## Temas

| # | Archivo | Tema |
|---|---------|------|
| 1.1 | `1.1_Magnitudes_Electricas.md` | Voltaje, corriente, resistencia, potencia, Ley de Ohm |
| 1.2 | `1.2_Senales.md` | Señales analógicas vs digitales, ruido, frecuencia, duty cycle |
| 1.3 | `1.3_Logica_Booleana.md` | Álgebra booleana, puertas lógicas, tablas de verdad |
| 1.4 | `1.4_Circuitos_Secuenciales.md` | Flip-flops, latches, registros, contadores |
| 1.5 | `1.5_Representacion_de_Datos.md` | Binario, complemento a 2, ASCII/Unicode, endianness |

## Dependencias

Ninguna. Este es el módulo fundacional.

## Conexión con el sistema

Sin entender que un transistor opera como un switch controlado por voltaje, que las puertas lógicas implementan álgebra booleana, y que los flip-flops almacenan bits, no se puede comprender cómo una CPU ejecuta instrucciones ni cómo la memoria retiene datos. Todo lo que sigue — CPU, cache, buses, NIC — es una composición de estos bloques primitivos.
