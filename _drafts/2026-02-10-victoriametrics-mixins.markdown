---
layout: post
title: "VictoriaMetrics observability from day one - Mixins on Grafana, VictoriaMetrics and vmagent"
categories: Kubernetes Observability
tags:   Kubernetes Grafana VictoriaMetrics vmagent Mixins Observability
date:   2026-02-10 00:00:00+0000
---

In a [previous post](/kubernetes-observability/2025/06/26/kubernetes-mixins.html), I explored how to set up observability using Kubernetes Mixins with Grafana Mimir and Alloy. It was a great exercise, but the stack was... heavy. Distributed systems are great fun 🤔, most of the time we should just stick to a simpler setup.

Enter VictoriaMetrics.

I've been wanting to try VictoriaMetrics for a while. It should be performant, resource-efficient, and apparently it works as a drop-in replacement for Prometheus. So, why not put it to the test and see how it fares with Kubernetes Mixins?


## The Stack

Instead of Alloy and Mimir, we are going to use:

- **vmagent**: A tiny but mighty agent that scrapes metrics and forwards them. It replaces Prometheus server (for scraping) and handles relabeling with impressive efficiency.
- **VictoriaMetrics**: The long-term storage. You can run it as a single binary or a cluster. For most of us, the single node version is already overkill in terms of performance.

## Kubernetes Mixins... again?

Yes, the goal is the same. We want to use the community's knowledge to monitor our cluster. The [kubernetes-mixin](https://github.com/kubernetes-monitoring/kubernetes-mixin) is still the source of truth.

However, the default mixin configuration assumes a standard Prometheus setups. When using the VictoriaMetrics stack (specifically the [victoria-metrics-k8s-stack](https://github.com/VictoriaMetrics/helm-charts/tree/master/charts/victoria-metrics-k8s-stack) Helm chart), the job names and labels might differ slightly.

But hey! That's exactly what mixins are for!

### Project Setup

We start with the same `jsonnetfile.json` to pull in the dependencies.

```json
{
  "version": 1,
  "dependencies": [
    {
      "source": {
        "git": {
          "remote": "https://github.com/kubernetes-monitoring/kubernetes-mixin",
          "subdir": ""
        }
      },
      "version": "master"
    }
  ],
  "legacyImports": true
}
```

Then we install the dependencies:

```bash
jb install
```

### The Configuration

This is where the magic happens. We need to tell the mixin where to find our metrics since the VictoriaMetrics Helm chart uses different job names than Grafana Alloy.

In `main.libsonnet`, we import the mixin and override the selectors. 

```jsonnet
local kubernetes = import 'kubernetes-mixin/mixin.libsonnet';

kubernetes {
  _config+:: {
    cadvisorSelector: 'job="kubernetes-cadvisor"',
    kubeletSelector: 'job="kubernetes-nodes"',
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
    nodeExporterSelector: 'job="node-exporter"',
    kubeSchedulerSelector: 'job="kube-scheduler"',
    kubeControllerManagerSelector: 'job="kube-controller-manager"',
    kubeApiserverSelector: 'job="kubernetes-apiservers"',
  },
}
```

The beauty of this is that we are just changing a few lines of configuration code. The logic for the alerts and dashboards remains untouched, maintained by the community.

### Packaging for Kubernetes

This is where we stopped in the [previous post](/kubernetes-observability/2025/06/26/kubernetes-mixins.html). We did not package the alerts and dashboards for Kubernetes. We just hacked a few scripts together to apply the JSON files to our cluster.

Since we are already using Jsonnet, we can write a small wrapper `k8s.libsonnet` to import our configuration and wrap the output in the correct Kubernetes resources:
- `VMRule`: The Custom Resource used by the VictoriaMetrics Operator for alerts and recording rules.
- `ConfigMap`: To mount dashboards into Grafana (using the sidecar pattern).

```jsonnet
local mixin = import 'main.libsonnet';

// Helper to sanitize names for K8s resources
local sanitizeName(s) = std.strReplace(std.asciiLower(s), '_', '-');

{
  // WRAPPER: VMRule (VictoriaMetrics Operator CRD)
  local vmRule(name, groups) = {
    apiVersion: 'operator.victoriametrics.com/v1beta1',
    kind: 'VMRule',
    metadata: {
      name: name,
      namespace: 'monitoring',
    },
    spec: {
      groups: groups,
    },
  },

  // WRAPPER: ConfigMap (Grafana Dashboards)
  local dashboardCm(name, content) = {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'grafana-dashboard-' + sanitizeName(name),
      namespace: 'monitoring',
      labels: {
        grafana_dashboard: '1', // Label for the Grafana sidecar to find it
      },
    },
    data: {
      [name + '.json']: std.toString(content),
    },
  },

  // OUTPUT LIST
  apiVersion: 'v1',
  kind: 'List',
  items: [
    // 1. Alert Rules
    vmRule('mixin-alerts', mixin.prometheusAlerts.groups),
    
    // 2. Recording Rules
    vmRule('mixin-rules', mixin.prometheusRules.groups),
  ] + [
    // 3. Dashboards 
    dashboardCm(name, mixin.grafanaDashboards[name])
    for name in std.objectFields(mixin.grafanaDashboards)
  ],
}
```

Now we can generat the final manifests is a single command:

```bash
jsonnet -J vendor k8s.libsonnet > manifests.yaml
```

The result is a clean `manifests.yaml` that you apply or commit.

```bash
kubectl apply -f manifests.yaml
```

## Test it out

You can test this setup locally on [Kind](https://kind.sigs.k8s.io/), head over to [driv/blog-victoriametrics-mixin-example](https://github.com/driv/blog-victoriametrics-mixin-example) and follow the README.

## Conclusion

Switching the backend from Mimir/Alloy to VictoriaMetrics was surprisingly painless thanks to the Mixins. The abstractions work!

