package main

# Deny ingress rules that open SSH (port 22) to the world.
deny[msg] {
	r := input.resource_changes[_]
	r.type == "aws_security_group_rule"
	r.change.after.type == "ingress"
	r.change.after.from_port <= 22
	r.change.after.to_port >= 22
	"0.0.0.0/0" == r.change.after.cidr_blocks[_]
	msg := sprintf("SG rule %s opens SSH to 0.0.0.0/0", [r.address])
}
