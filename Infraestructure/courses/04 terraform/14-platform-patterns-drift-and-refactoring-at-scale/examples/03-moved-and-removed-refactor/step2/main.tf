# After the refactor:
#  - old_name -> new_name (declarative rename via `moved`)
#  - handoff_candidate removed from this state WITHOUT destroying the file on disk
#    (destroy = false), so another stack can adopt it later via `import {}`.

resource "local_file" "new_name" {
  filename        = "/tmp/tf14-ex03/data/to-rename.txt"
  content         = "will be renamed via moved {}\n"
  file_permission = "0644"
}

moved {
  from = local_file.old_name
  to   = local_file.new_name
}

removed {
  from = local_file.handoff_candidate

  lifecycle {
    destroy = false
  }
}
