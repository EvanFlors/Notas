package main

test_denies_latest if {
	some msg in deny with input as {
		"kind": "Deployment",
		"metadata": {"name": "bad"},
		"spec": {"template": {"spec": {"containers": [{"name": "c", "image": "nginx:latest"}]}}},
	}
	contains(msg, "latest")
}

test_denies_no_tag if {
	some msg in deny with input as {
		"kind": "Pod",
		"metadata": {"name": "bad"},
		"spec": {"containers": [{"name": "c", "image": "nginx"}]},
	}
	contains(msg, "no tag")
}

test_allows_pinned_tag if {
	not deny_any with input as {
		"kind": "Pod",
		"metadata": {"name": "good"},
		"spec": {"containers": [{"name": "c", "image": "nginx:1.27"}]},
	}
}

test_allows_digest if {
	not deny_any with input as {
		"kind": "Pod",
		"metadata": {"name": "good"},
		"spec": {"containers": [{"name": "c", "image": "nginx@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]},
	}
}

deny_any if {
	some _ in deny
}
