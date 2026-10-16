.PHONY: render clean check

render:
	jsonnet dashboard.jsonnet > rendered.json
	@echo "Rendered: $$(wc -l < rendered.json) lines"

clean:
	rm -f rendered.json

check:
	@test -f rendered.json || (echo "run 'make render' first" >&2; exit 1)
	@jq -e '.uid' rendered.json >/dev/null
	@echo "rendered.json looks like a valid dashboard"
