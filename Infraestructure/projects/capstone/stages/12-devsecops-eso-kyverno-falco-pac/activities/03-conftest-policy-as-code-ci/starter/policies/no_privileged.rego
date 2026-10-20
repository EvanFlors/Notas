package main

# BUG: alguien "simplifico" la regla de hostPath y le quito el `some`.
# Resultado: la expresion no itera sobre volumes y nunca dispara. Arreglalo.

pod_spec := input.spec if input.kind == "Pod"

pod_spec := input.spec.template.spec if {
	input.kind in {"Deployment", "StatefulSet", "DaemonSet"}
}

deny contains msg if {
	some c in pod_spec.containers
	c.securityContext.privileged == true
	msg := sprintf("container %q in %s/%s is privileged", [c.name, input.kind, input.metadata.name])
}

# BUG aqui ↓↓↓
deny contains msg if {
	pod_spec.volumes[0].hostPath
	msg := "hostPath volume detected"
}
