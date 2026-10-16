// solution/dashboard.jsonnet
// Reference solution — one way to express the RED dashboard in jsonnet.
// Students are expected to design their own structure; this is an example.

local ds = { type: 'prometheus', uid: 'prom-main' };

local target(expr, legend='', extras={}) = {
  refId: 'A',
  expr: expr,
  [if legend != '' then 'legendFormat']: legend,
} + extras;

local panel(id, type, title, targets, gridPos, extras={}) = {
  id: id,
  type: type,
  title: title,
  datasource: ds,
  gridPos: gridPos,
  targets: targets,
} + extras;

local rateByHandler = 'sum by (handler) (rate(prometheus_http_requests_total{job=~"$job"}[$__rate_interval]))';
local errorRatio = 'sum(rate(prometheus_http_requests_total{code=~"5..",job=~"$job"}[$__rate_interval])) / clamp_min(sum(rate(prometheus_http_requests_total{job=~"$job"}[$__rate_interval])), 1)';
local p95 = 'histogram_quantile(0.95, sum by (le) (rate(prometheus_http_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval])))';
local heat = 'sum by (le) (rate(prometheus_http_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval]))';
local topHandlers = 'topk(10, histogram_quantile(0.95, sum by (handler, le) (rate(prometheus_http_request_duration_seconds_bucket{job=~"$job"}[$__rate_interval]))))';
local upByInstance = 'up{job=~"$job"}';

local vars = [
  {
    name: 'job',
    type: 'query',
    datasource: ds,
    query: 'label_values(up, job)',
    refresh: 1,
    includeAll: true,
    multi: true,
    allValue: '.+',
  },
  {
    name: 'interval',
    type: 'custom',
    query: '1m,5m,15m,1h',
    current: { text: '5m', value: '5m' },
    options: [
      { text: '1m', value: '1m' },
      { text: '5m', value: '5m', selected: true },
      { text: '15m', value: '15m' },
      { text: '1h', value: '1h' },
    ],
  },
];

local panels = [
  panel(1, 'timeseries', 'Rate — requests/s por handler',
        [target(rateByHandler, '{{handler}}')],
        { h: 8, w: 12, x: 0, y: 0 },
        { fieldConfig: { defaults: { unit: 'reqps' }, overrides: [] } }),
  panel(2, 'stat', 'Error ratio',
        [target(errorRatio)],
        { h: 8, w: 6, x: 12, y: 0 },
        { fieldConfig: { defaults: { unit: 'percentunit' }, overrides: [] } }),
  panel(3, 'gauge', 'p95 latency (s)',
        [target(p95)],
        { h: 8, w: 6, x: 18, y: 0 },
        { fieldConfig: { defaults: { unit: 's', min: 0, max: 1 }, overrides: [] } }),
  panel(4, 'heatmap', 'Latency distribution',
        [target(heat, '{{le}}', { format: 'heatmap' })],
        { h: 8, w: 12, x: 0, y: 8 }),
  panel(5, 'table', 'Top 10 handlers por p95',
        [target(topHandlers, '', { instant: true, format: 'table' })],
        { h: 8, w: 12, x: 12, y: 8 }),
  panel(6, 'state-timeline', 'up por target',
        [target(upByInstance, '{{instance}}')],
        { h: 6, w: 24, x: 0, y: 16 }),
];

{
  uid: 'capstone-red',
  title: 'RED — capstone',
  tags: ['capstone', 'red'],
  schemaVersion: 39,
  version: 1,
  refresh: '30s',
  time: { from: 'now-30m', to: 'now' },
  templating: { list: vars },
  panels: panels,
}
