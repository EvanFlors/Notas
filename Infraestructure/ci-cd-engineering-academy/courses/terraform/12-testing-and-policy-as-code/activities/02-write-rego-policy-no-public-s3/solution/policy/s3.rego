package main

# Set of ACL values considered public.
public_acls := {"public-read", "public-read-write"}

# Regla 1: ningun aws_s3_bucket_acl puede tener un ACL publico.
deny[msg] {
	r := input.resource_changes[_]
	r.type == "aws_s3_bucket_acl"
	r.change.after.acl == acl
	public_acls[acl]
	msg := sprintf("S3 ACL %s uses public acl=%q", [r.address, acl])
}

# --- Correlacion bucket <-> BPA por nombre ---

bucket_names[name] {
	r := input.resource_changes[_]
	r.type == "aws_s3_bucket"
	name := r.change.after.bucket
}

bpa_targets[name] {
	r := input.resource_changes[_]
	r.type == "aws_s3_bucket_public_access_block"
	name := r.change.after.bucket
}

# Regla 2: todo bucket debe tener un aws_s3_bucket_public_access_block asociado.
deny[msg] {
	bucket := bucket_names[_]
	not bpa_targets[bucket]
	msg := sprintf("bucket %q has no aws_s3_bucket_public_access_block", [bucket])
}
