resource "local_file" "old_name" {
  filename        = "/tmp/tf14-ex03/data/to-rename.txt"
  content         = "will be renamed via moved {}\n"
  file_permission = "0644"
}

resource "local_file" "handoff_candidate" {
  filename        = "/tmp/tf14-ex03/data/handoff.txt"
  content         = "will be handed off via removed { destroy = false }\n"
  file_permission = "0644"
}
