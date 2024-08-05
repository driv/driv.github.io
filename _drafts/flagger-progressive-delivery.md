---
layout: post
title: "Indistructible applications with progressive delivery"
categories: Blog
tags: Flagger Fluxcd Kubernetes
---
Progressive delivery allows to put a new version of the application in production while keeping the previous one running and control how much traffic each get.

## Strategies
#### Replicas Rollout
Progressively increasing the number of replicas of the new version while taking the old one down to zero.
#### Traffic Split
Through some network mechanism (Load balancer, Ingress, Mesh, Network Interface) the traffic gets progressively shifted to the new version of the application.
#### Feature Flags
This is not a deployment strategy, but a release strategy.

The application itself "decides" when to expose the new functionality based on some feature flag. It has the flexibility of rolling out randomly or by client, type of client, user, location etc. It allows us to separate deployment from release.

<br>
<br>
<br>
<br>

Each of these approaches has it's merits and drawbacks. It's possible to use Replicas Rollout or Traffic Split during deployment and Feature Flags to release the functionality to the users.

### Why should we deliver progressively?

Through progressive delivery we try to reduce both the risk and the impact of a new (bad) deployment. It gives us the chance and the time to analyse the behavior of our application in the production environment with real traffic. Since the old version of the application is still running, the rollback can be much faster, reducing our [MTTR](https://www.ibm.com/topics/mttr).

# Flagger: progressive delivery in Kubernetes
Part of the FluxCD ecosystem, Flagger can do progressive delivery for us. It supports [multiple mechanisms](https://github.com/fluxcd/flagger/?tab=readme-ov-file#features) but today we'll be using Nginx `Ingress`.

## Canary

The new version of the application that slowly starts getting traffic is called canary (from the canaries used as [sentinels](https://en.wikipedia.org/wiki/Sentinel_species) in coal mines). 

```
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: app
  namespace: default
spec:
  provider: nginx
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
[...]
```

A `Canary` references a `Deployment` and it manages it for us.

## Quirks
There are a few things that might be counterintuitive when using Flagger.

#### We define the Canary Deployment.

The `Deployment` we define in our manifests is **not** the primary one but it's the canary Deployment.

Flagger will create a "shadow" `Deployment` with `name: <deployment_name>-primary`. The `Pods` from the "shadow" deployment will normally handle production traffic. We should not modify this `Deployment`, it's managed by Flagger.

The `Deployment` we define is normally scaled to 0, unless a deployment of a new version is happening, in which case it's `Pods` will have the new version of the application.

#### Canaries get discarded.

Once the analysis is successful and the canary is promoted, the canary `Pods` don't become the primary.

While the canary instances are running, the primary `Deployment` gets updated with the new version and re-deployed. Once the new version is up and running on the primary deployment, the canary `Deployment` gets scaled down to 0.

## Sequence of events
<object id="sequence-of-events-animation" type="image/svg+xml" data="/public/posts_assets/flagger-progressive-delivery/sequence-of-events.svg" width="100%">
  Your browser does not support SVG
</object>
<small>Sequence of events for a Canary Promotion (Click the `Deploy!` button to start).
<button onclick="var svg = document.getElementById('sequence-of-events-animation'); svg.setAttribute('data', svg.getAttribute('data'));">Reset</button>
</small>

#### Sequence:
- Deployment version change: It can be done manually or by any external tool (FluxCD, ArgoCD, etc.):
  - `name: app`
  - `image: image:v1->image:v2`
- Flagger increases the number of replicas for the canary deployment (the primary deployment stays the unchanged).
  - `name: app`
  - `replicas: 0->1`
- Flagger starts sending some traffic to the canary service.
- Flagger validates the health of the new pods. If the new version fails any validation it gets scaled down to 0, the release is aborted.
- Flagger increases the traffic to the canary service and keeps running the analysis.
- Flagger copies the canary configuration to the primary.
  - `name: app-primary`
  - `image: image:v1->image:v2` 
- Flagger scales down the canary deployment.
  - `name: app`
  - `replicas: 1->0`

## Analysis
How does flagger know if our canary is ok?

The same way we (should) know: **metrics!**

Part of the `Canary` `analysis` definition are metrics.

```
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: app
  namespace: default
spec:
[...]
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: response-duration
      thresholdRange:
        max: 100
      interval: 1m
```

Flagger ships out-of-the box with `request-success-rates` and `request-duration` queries that it can get from Prometheus. We can also add our own queries.

### Analysis failure

By default flagger will retry running the analysis, since it can fail to run for many reasons. e.g. the metric is not available right away when the Canary deployment starts

If the analysis keeps failing the release is aborted. Since the primary deployment has not been modified in any way, Flagger only needs to scale down the number of replicas in the Canary deployment to 0.

## Metric Template

We can define our own metrics with a `MetricTemplate` and reference them from our canary.

For example: the default `request-success-rate` considers success anything that is not a 500 error, but we might want consider 2xx and 3xx responses only.

```
apiVersion: flagger.app/v1beta1
kind: MetricTemplate
metadata:
  name: strict-request-success-rate
  namespace: default
spec:
  provider:
    type: prometheus
    address: http://flagger-prometheus.ingress-nginx:9090
  query: |
    sum(
      rate(
        nginx_ingress_controller_requests{
          namespace="{{ namespace }}",
          ingress="{{ ingress }}",
          canary!="",
          status~="[23].*"
        }[{{ interval }}]
      )
    ) 
    / 
    sum(
      rate(
        nginx_ingress_controller_requests{
          namespace="{{ namespace }}",
          ingress="{{ ingress }}",
          canary!=""
        }[{{ interval }}]
      )
    ) 
    * 100
```

We can now reference this template in our `Canaries` using `templateRef`:
```
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: golang-api
  namespace: default
spec:
[...]
    metrics:
    - name: request-success-rate
      templateRef:
        name: strict-request-success-rate
        namespace: default
      thresholdRange:
        min: 99
      interval: 1m
```


# Try it out!

Check out this repo.
Try using a slow or broken version of the application and see how Flagger will stop you from completely breaking "production".

You'll find all the instructions in the Readme.

