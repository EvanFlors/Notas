// service.libsonnet — reusable RED dashboard template.
// Instantiate per service: `service.new('checkout', 'payments', 'prod')`.
//
// This is a minimal, dependency-free jsonnet that produces a Grafana v11
// dashboard JSON with 3 panels: Rate, Errors (ratio), Duration p95.
// In a real repo you would import grafana/grafonnet-lib for richer helpers;
// kept bare here so the example runs with vanilla `jsonnet` only.

{
  // Build a panel spec.
  panel(id, title, unit, exprs)::
    {
      id: id,
      type: 'timeseries',
      title: title,
      datasource: { type: 'prometheus', uid: 'prom' },
      gridPos: { x: ((id - 1) * 8) % 24, y: 0, w: 8, h: 8 },
      fieldConfig: {
        defaults: {
          unit: unit,
          custom: { lineWidth: 2, fillOpacity: 10 },
        },
      },
      targets: [
        { refId: 'A' + std.toString(i), expr: exprs[i], legendFormat: '{{route}}' }
        for i in std.range(0, std.length(exprs) - 1)
      ],
    },

  // Build the dashboard for a given service.
  new(service, team, env)::
    {
      title: '[' + team + '] ' + service + ' - RED (' + env + ')',
      uid: team + '-' + service + '-red',
      tags: ['red', 'service:' + service, 'team:' + team, 'env:' + env, 'generated'],
      schemaVersion: 39,
      version: 1,
      timezone: 'browser',
      refresh: '30s',
      time: { from: 'now-6h', to: 'now' },
      templating: {
        list: [
          {
            name: 'service',
            type: 'constant',
            query: service,
            hide: 2,
          },
        ],
      },
      panels: [
        $.panel(
          1,
          'Rate (requests/s)',
          'reqps',
          [
            'sum by (route) (rate(http_requests_total{service="' + service + '",env="' + env + '"}[5m]))',
          ]
        ),
        $.panel(
          2,
          'Errors (ratio)',
          'percentunit',
          [
            '(sum by (route) (rate(http_requests_total{service="' + service + '",env="' + env + '",status=~"5.."}[5m])))'
            + ' / (sum by (route) (rate(http_requests_total{service="' + service + '",env="' + env + '"}[5m])))',
          ]
        ),
        $.panel(
          3,
          'Duration p95 (s)',
          's',
          [
            'histogram_quantile(0.95, sum by (le, route) (rate(http_request_duration_seconds_bucket{service="'
            + service + '",env="' + env + '"}[5m])))',
          ]
        ),
      ],
    },
}
