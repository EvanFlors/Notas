resource "random_pet" "greeting" {
  length    = 2
  separator = "-"
}

resource "random_integer" "port" {
  min = 1024
  max = 65535
}

resource "local_file" "hello" {
  filename        = "${path.module}/hello.txt"
  content         = "hola ${random_pet.greeting.id} en puerto ${random_integer.port.result}\n"
  file_permission = "0644"
}
