# ERROR 4 (formato): este bloque esta mal indentado a proposito.
# 'terraform validate' NO lo detecta — solo 'terraform fmt -check' lo marca.
# Pista: corrige la indentacion con 2 espacios dentro del bloque.
provider "local" {
    # dentro del bloque se usan 4 espacios en vez de 2
    # (local no requiere configuracion especial, es solo para forzar el fmt)
}

provider "random" {
}
