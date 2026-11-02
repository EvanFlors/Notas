#!/usr/bin/env bash
# demo.sh — aritmética entera en Bash y punto flotante con bc.
set -euo pipefail

echo "== Aritmética entera con \$(( )) y (( )) =="
a=20
b=6
echo "  a=$a  b=$b"
echo "  a + b         = $((a + b))"
echo "  a - b         = $((a - b))"
echo "  a * b         = $((a * b))"
echo "  a / b (entero)= $((a / b))"
echo "  a % b         = $((a % b))"
echo "  b ** 3        = $((b ** 3))"

counter=0
(( counter++ ))
(( counter++ ))
(( counter += 5 ))
echo "  counter tras ++, ++, +=5 = $counter"

echo
echo "== Bases numéricas =="
echo "  0755 octal     en decimal = $((0755))"
echo "  0xff hex       en decimal = $((0xff))"
echo "  2#1010 binario en decimal = $((2#1010))"

echo
echo "== Operadores bit a bit =="
echo "  5 | 3  = $((5 | 3))"
echo "  5 & 3  = $((5 & 3))"
echo "  5 ^ 3  = $((5 ^ 3))"
echo "  1 << 4 = $((1 << 4))"

echo
echo "== Punto flotante con bc -l =="
usado=37
total=120
porcentaje_2dec=$(echo "scale=2; $usado * 100 / $total" | bc -l)
porcentaje_6dec=$(echo "scale=6; $usado * 100 / $total" | bc -l)
echo "  usado=$usado  total=$total"
echo "  porcentaje (2 dec) = ${porcentaje_2dec}%"
echo "  porcentaje (6 dec) = ${porcentaje_6dec}%"

promedio=$(echo "scale=3; (12.5 + 7.25 + 9.75) / 3" | bc -l)
echo "  promedio(12.5, 7.25, 9.75) = $promedio"

echo
echo "== Comparar floats (bc -> (( )) ) =="
valor="0.87"
umbral="0.90"
if (( $(echo "$valor > $umbral" | bc -l) )); then
  echo "  $valor > $umbral : V"
else
  echo "  $valor > $umbral : F"
fi

if (( $(echo "$valor >= 0.80" | bc -l) )); then
  echo "  $valor >= 0.80  : V"
else
  echo "  $valor >= 0.80  : F"
fi

echo
echo "FIN."
