=== 1 ===
echo {a,b,c}
=== 2 ===
n=3; echo {1..$n}
=== 3 ===
s="hello world"; echo "${#s}"
=== 4 ===
path=/var/log/app.log; echo "${path##*/}"
=== 5 ===
path=/var/log/app.log; echo "${path%.*}"
=== 6 ===
s="foo,bar,baz"; echo "${s//,/ }"
=== 7 ===
name=linux; echo "${name^^}"
=== 8 ===
unset v; echo "${v:-fallback}"
=== 9 ===
v="x"; echo "${v:+set}"
=== 10 ===
arr=(a b "c d"); printf '%s\n' "${arr[@]}"
=== 11 ===
arr=(a b "c d"); IFS=,; echo "${arr[*]}"
=== 12 ===
echo $((2 ** 10))
=== 13 ===
v=foo; echo "${v/o/0}"
=== 14 ===
v=foo; echo "${v//o/0}"
=== 15 ===
shopt -s nullglob; files=( *.absent ); echo "count=${#files[@]}"
