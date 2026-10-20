package main

# Fix: iterar sobre volumes con `some v in pod_spec.volumes` para disparar
# una vez por cada volumen con hostPath. El bug era asumir que hostPath
# siempre esta en el indice 0.

pod_spec := input.spec if input.kind == "Pod"

pod_spec := input.spec.template.spec if {
	input.kind in {"Deployment", "StatefulSet", "DaemonSet"}
}

deny contains msg if {
	some c in pod_spec.containers
	c.securityContext.privileged == true
	msg := sprintf("container %q in %s/%s is privileged", [c.name, input.kind, input.metadata.name])
}

deny contains msg if {
	some v in pod_spec.volumes
	v.hostPath
	msg := sprintf("%s/%s mounts hostPath volume %q", [input.kind, input.metadata.name, v.name])
}
