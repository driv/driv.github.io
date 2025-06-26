---
layout: post
title: "Kubernetes observability from day one - Mixins on Grafana, Mimir and Alloy"
categories: Kubernetes Observability
tags:   Kubernetes Grafana Mimir Alloy Mixins Observability
date:	05/06/2025 00:00:00+0000
---

One of the things we quickly find out when using Kubernetes is that it's hard to know what is going on. In many cases, we implement monitoring and alerting after we've dealt with problems, but there is a better way.

We don't need to wait for the explosions, we can re-use the community's knowledge and implement observability from the beginning.

## What are Mixins?

The concept of a mixin comes from object-oriented programming, where a mixin is a class that provides methods that can be used to extend the capability of other objects without being inherited.

In the context of observability, it's a set of reusable configurable components that we can use to implement monitoring and alerting. Allowing to share knowledge and best practices.

### Why do we need Mixins?

It would be great if we could all agree on metrics and labels, so we could just import dashboards and alerts. But that's far from reality.

Because of different tools, configurations, environments, historical reasons, etc. we need a way to adapt the monitoring setup to our environment.

For example: what name do you use for the label to identify pods? Is it `pod`, `pod_name`, `kubernetes_pod` or something else? What about the namespace? Do you use `namespace`, `k8s_namespace`, `kubernetes_namespace`? What about nodes? `node`, `instance_name`, `instance`?

Do you have multiple clusters? Multiple scraping jobs? Are you using Prometheus, Prometheus operator, Alloy, Cortex?

As you can see the possibilities are combinatorial. Mixins can adapt to our configuration.

### Libsonnet, Jsonnet and Jsonnet-bundler

Mixins for observability are typically written in [Jsonnet](https://jsonnet.org/), a data templating language that makes it easy to generate JSON or YAML.

**Libsonnet** is just a `.libsonnet` file extension, indicating a Jsonnet library that can be imported and reused.

**Jsonnet-bundler** (`jb`) is a package manager for Jsonnet, can fetch and manage mixin dependencies.

This approach allows you to keep your monitoring configuration as code, version it, and easily adopt community best practices into your environment.

That's useful in 2 ways, first by providing some kind of templating for json or YAML, and second by allowing to import libraries that can be reused across different mixins.

We can see this in action with the grafana dashboards, the first line imports the grafonnet grafana library:

```libsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local timeSeries = g.panel.timeSeries;
local var = g.dashboard.variable;

{
  local statPanel(title, unit, query) =
    stat.new(title)
    + stat.options.withColorMode('none')
    + stat.standardOptions.withUnit(unit)
    + stat.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
    + stat.queryOptions.withTargets([
      prometheus.new('${datasource}', query)
      + prometheus.withInstant(true),
    ]),

  local tsPanel =
    timeSeries {
      new(title):
        timeSeries.new(title)
        + timeSeries.options.legend.withShowLegend()
        + timeSeries.options.legend.withAsTable()
        + timeSeries.options.legend.withDisplayMode('table')
        + timeSeries.options.legend.withPlacement('right')
        + timeSeries.options.legend.withCalcs(['lastNotNull'])
        + timeSeries.options.tooltip.withMode('single')
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withSpanNulls(true)
        + timeSeries.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval),
    },
  ...
```

This would be too complex for configuration that does not get shared across multiple projects.

## Grafana Alloy

Before being able to visualize and alert on the metrics, we need to collect them. Alloy is an all-in-one solution to collect, process, and ship metrics.

It's able to replace multiple components in the observability stack, such as Prometheus (for scraping, not storing), Node Exporter, Promtail, OTel Collector, and more.

Alloy is a Grafana Labs product, and it is available as a managed service and as an open-source project. You can find more information at [grafana.com/alloy](https://grafana.com/alloy).

Since it does so much, the configuration is not trivial, but the [grafana/k8s-monitoring-helm](https://github.com/grafana/k8s-monitoring-helm/tree/main/charts/k8s-monitoring) Helm chart can save us a lot of time.

There is quite a lot packed into this chart, today we are interested in a few components:

```yaml
alloy-metrics:
  enabled: true
clusterMetrics:
  enabled: true
  controlPlane:
    enabled: true
```

That's all we need to enable Alloy to collect metrics from our cluster. It will not only configure Alloy to scrape the metrics, but it will also install metrics-server to expose the Kubernetes metrics API.

The next step is to ship these metrics somewhere. We can use Grafana Mimir as a destination for our metrics.

```yaml
destinations:
- name: local-mimir
  type: prometheus
  url: http://mimir-nginx.monitoring.svc.cluster.local.:80/api/v1/push
```

## Grafana Mimir

Another Grafana Labs product. Let's let Copilot explain it:
> Mimir is a horizontally scalable, highly available, multi-tenant, long-term storage for Prometheus metrics. It is the successor of Cortex and is designed to handle large amounts of metrics data.

I would call it a distributed Prometheus with long term storage (in s3 for example).
Compared to Prometheus is a lot more complex to set up, but it should give us a few extra "[ilities](https://en.wikipedia.org/wiki/List_of_system_quality_attributes)". In practice, it's easier to horizontally scale.

Again, Helm comes to our rescue. The [grafana/mimir-helm](https://github.com/grafana/helm-charts/tree/main/charts/mimir-distributed) Helm chart can be used.

This is the minimum size I was able to achieve. Not great for a small development environment, it's still an overkill, but there is no 'non-distributed' Mimir setup.

```yaml
mimir:
  structuredConfig:
  ingester:
    ring:
    replication_factor: 1
ingester:
  #Ingester must have 2 replicas
  replicas: 2
  zoneAwareReplication:
      enabled: false
store_gateway:
  replicas: 1
  zoneAwareReplication:
      enabled: false
federationFrontend:
  replicas: 1
minio:
  replicas: 1
querier:
  replicas: 1
query_scheduler:
  replicas: 1
```

## Kubernetes Mixins

Since we want to keep an eye on our cluster, we'll use the Kubernetes Mixin. We can find it in [kubernetes-monitoring/kubernetes-mixin](https://github.com/kubernetes-monitoring/kubernetes-mixin)

It is a collection of configurable components (alerts, recording rules and dashboards) that can give us a good overview of our cluster. It can also bring some basic application monitoring, since it can keep an eye on failed deployments, stuck jobs, resource usage, etc.

### JSON generation

The output of the mixin is a collection of JSON files based on the configuration we provide.

Mixins are defined in [Jsonnet](https://jsonnet.org/).
We use [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler) to generate our files files from the mixin.

We need to provide a configuration file to override the defaults, in this case we want our monitoring to adapt to our Alloy and Mimir setup.

```jsonnet
local kubernetes = import "kubernetes-mixin/mixin.libsonnet";

kubernetes {
  _config+:: {
    cadvisorSelector: 'job="integrations/kubernetes/cadvisor"',
    kubeletSelector: 'job="integrations/kubernetes/kubelet"',
    kubeStateMetricsSelector: 'job="integrations/kubernetes/kube-state-metrics"',
    nodeExporterSelector: 'job="integrations/node_exporter"',
    kubeSchedulerSelector: 'job="kube-scheduler"',
    kubeControllerManagerSelector: 'job="kube-controller-manager"',
    kubeApiserverSelector: 'job="integrations/kubernetes/kube-apiserver"',
    kubeProxySelector: 'job="integrations/kubernetes/kube-proxy"',
    podLabel: 'pod',
    hostNetworkInterfaceSelector: 'device!~"veth.+"',
    hostMountpointSelector: 'mountpoint="/"',
    windowsExporterSelector: 'job="integrations/windows_exporter"',
    containerfsSelector: 'container!=""',

    grafanaK8s+:: {
      dashboardTags: ['kubernetes', 'infrastructure'],
    },
  },
}
```

We are importing the `kubernetes-mixin/mixin.libsonnet`. Where did that come from? From the Kubernetes Mixin repository, but we need to install it first.

```bash
cd mixins
jb init

# This will install the kubernetes-mixin to the ./vendor directory
jb install https://github.com/kubernetes-monitoring/kubernetes-mixin
```

You can now put your configuration in a file `mixin.libsonnet`. We have overridden only what we need to change from the [default](https://github.com/kubernetes-monitoring/kubernetes-mixin/blob/master/config.libsonnet) configuration.

**We are ready to generate!**

```bash
jsonnet -J vendor -S -e 'std.manifestYamlDoc((import "mixin.libsonnet").prometheusAlerts)' > generated/alerts.yml
jsonnet -J vendor -S -e 'std.manifestYamlDoc((import "mixin.libsonnet").prometheusRules)' > generated/rules.yml

mkdir -p generated/dashboards
jsonnet -J vendor -m generated/dashboards -e '(import "mixin.libsonnet").grafanaDashboards'
```

### Deploying the generated files

Here things get murky, there are multiple options and no clear winner.
I would say that this should be treated like code, put under version control, and through CI to generate the files.

We have 2 quite different outputs: Prometheus rules (alerts and recording rules), and Grafana dashboards.

#### Alerts and Rules

Alerts and rules need to get both imported as rules into Mimir, the alertmanager will read the alert rules and create alerts based on its configuration.

One option to make it more GitOps friendly, would be to generate `PrometheusRule` [resources](https://github.com/prometheus-operator/prometheus-operator/blob/main/example/user-guides/alerting/prometheus-example-rules.yaml) from the generated files and apply them to the cluster. Alloy is able to read these resources and push them to Mimir.

Today we'll keep it simple and just use `mimirtool` to import the rules and alerts directly into Alloy. Let's port forward the alloy-metrics service and push them.

```bash
mimirtool rules load --address=http://localhost:8080 --id=anonymous generated/alerts.yml 
mimirtool rules load --address=http://localhost:8080 --id=anonymous generated/rules.yml 
```

#### Grafana Dashboards

Here too, multiple options, no clear winner. If we were using the operator we could use the `GrafanaDashboard` resources.

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: apiserver
  namespace: monitoring
spec:
  json: >
    {
       "editable": false,
        ...
       "panels": [
          {
             "datasource": {
                "type": "datasource",
                "uid": "-- Mixed --"
             },
             "description": "The SLO (service level objective) and other metrics displayed on this dashboard are for informational purposes only.",
        ...

```

Another option would be to use the the grafana API and import the dashboards with `curl` or `grafana-cli`.

```bash
curl -X POST http://localhost:3000/apis/dashboard.grafana.app/v1beta1/namespaces/default/dashboards \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <YOUR_SERVICE_ACCOUNT_TOKEN>" \
  -d @mixins/generated/dashboards/apiserver.json
```

What I ended up doing instead is using the grafana sidecar to read dashboards from `ConfigMaps`. We could put multiple dashboards in a single configmap but we have to stay below the 1MB size limit.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: apiserver
  namespace: monitoring
data:
  apiserver.json: |
    {
       "editable": false,
        ...
       "panels": [
          {
             "datasource": {
                "type": "datasource",
                "uid": "-- Mixed --"
             },
             "description": "The SLO (service level objective) and other metrics displayed on this dashboard are for informational purposes only.",
        ...
```

If you are using the grafana helm chart, you need to enable the sidecar. By default it only imports from the same namespace.

```yaml
sidecar:
  dashboards:
    enabled: true
```

We are done!

## Grafana

If we head over to Grafana, we will find more dashboards, alerts and rules that we could ever dreame of.

![Dashboards](/public/posts_assets/kubernetes-mixins/dashboards.png)

![Alerts](/public/posts_assets/kubernetes-mixins/alerts.png)

![Rules](/public/posts_assets/kubernetes-mixins/rules.png)

We can explore the dashboards and probably learn something new about our own cluster.

## What else to Monitor?

We were busy trying to get the Kubernetes Monitoring working, but we ended up adding more infrastructure that also needs monitoring. And guess what? There are mixins for that too!

The same principle applies: we don’t need to start from scratch. There are Mixins available for monitoring [Mimir](https://github.com/grafana/mimir/tree/main/operations), [Alloy](https://github.com/grafana/alloy/tree/main/operations/alloy-mixin), and [Grafana](https://github.com/grafana/grafana/tree/main/grafana-mixin) itself.

The repository [nlamirault/monitoring-mixins](https://github.com/nlamirault/monitoring-mixins) is the most comprehensive list I've come across, but there are probably many more out there.

## Test it out

You can test this setup locally on [Kind](https://kind.sigs.k8s.io/), just head over to [driv/blog-k8s-monitoring-mixin](https://github.com/driv/blog-k8s-monitoring-mixin) and follow the README.

## Conclusion

Grafana Alloy and Mimir work together out of the box but Mimir, due to its distributed architecture, is an overkill for most single-cluster setups.

Mixins are great, they can bring in an amount of knowledge and best practices that would take us a long time to gain on our own.
But things are still not fully mature, there is no clear strategy to implement GitOps for the generated files, which makes me think that the usage is not that widespread yet.

The building blocks are there. Don't wait for the explosions, start with observability from day one.
