---
layout: post
title: "Pulumi - Zitadel Configuration on the Operator"
categories: Infrastructure Kubernetes IaC
tags:   Pulumi Zitadel OIDC Kubernetes "Operator"
date:	05/05/2025 00:00:00+0000
---
<!-- markdownlint-disable MD033 MD025 -->
I've been wanting to try Pulumi for a while now. I love IaC but I've always liked strongly typed languages. I think they are a great way to avoid mistakes and incentivize refactoring.

I hate to test technologies in a vacuum, I prefer to have something concrete to work on, otherwise, it's impossible to uncover the issues you might face in the real world. So I thought it would be a good idea to try to configure [Zitadel](https://zitadel.com/) on Kubernetes with Pulumi.

Zitadel on its own would not be too useful, let's add a Grafana instance and configure a few roles.

All the code is available on the repository [driv/zitadel-pulumi](https://github.com/driv/zitadel-pulumi).

# Objective

I want a fully declarative configuration for Zitadel and Grafana on Kubernetes using Pulumi.

# The TOOLS

## Pulumi

According to ChatGPT:

> Pulumi is an open-source infrastructure as code tool that allows you to define and manage ~~cloud~~ resources using programming languages like TypeScript, Python, Go, and C#. It provides a modern approach to infrastructure management, enabling developers to use familiar programming constructs and libraries to provision and manage ~~cloud~~ resources.

Having a programming background I've always felt I was fighting tools like Terraform. The first iterations looked fine, but when trying to introduce abstractions things would quickly get complicated.

This could be considered a feature, having too much flexibility can make it difficult to understand the resulting configuration.

But I think that's where refactoring and being able to evolve your configuration comes in if used wisely.

For example, extracting a function with parameters in go is something any IDE can handle for you, allowing for a small step towards more reusable code (and configuration). The equivalent in Terraform is not that simple.

## Zitadel

When it comes to self-hosted IDPs, Zitadel is one of the new(er) kids on the block. Compared to Keycloak, it is much less resource-intensive but also less mature, missing some features I was taking for granted, like user groups.

For some reason, at some point, it had an operator, but that's [not available](https://github.com/zitadel/zitadel/pull/3195) anymore.

Configuration is done through a GRPC API using JWT tokens. The [helm chart](https://github.com/zitadel/zitadel-charts/tree/main) lets us define a "[machine user](https://github.com/zitadel/zitadel-charts/tree/main/examples/4-machine-user)" to interact with the API.

## Helmfile

[Helmfile](https://github.com/helmfile/helmfile?tab=readme-ov-file#installation) is a tool to manage multiple helm releases.

It allows you to define the configuration of your helm releases in a single file, making it easier to manage and deploy multiple applications.

Another great functionality is to convert Kustomize manifests to helm charts on the fly, allowing a single command to deploy the whole development environment acting like a Kubernetes-Compose.

I'll use it to deploy all the tools and extra configuration we need running on Kubernetes. In a production scenario, this would be handled by FluxCD or ArgoCD.

# First iteration: Local execution

We will install our infrastructure on a Kind cluster and execute the Pulumi configuration locally.

## Prerequisites

We'll need a [Kind](https://kind.sigs.k8s.io/) cluster to run everything and [our Helmfile](https://github.com/driv/zitadel-pulumi/blob/main/helmfile.yaml) to install the infrastructure components.

```bash
kind create cluster --name=zitadel-pulumi
helmfile apply
```

You might need to re-run the helmfile installation, the Ingress webhook might not be ready when the charts get installed.

You'll also need to expose the Ingress controller to access the Zitadel UI and API. I like to use [cloud-provider-kind](https://github.com/kubernetes-sigs/cloud-provider-kind?tab=readme-ov-file#installing-with-go-install). You should keep it running in the background.

To make my life easier, I also add the hostnames I'm using to the `/etc/hosts` file. Replace the IP with the external IP of your Ingress controller.

```bash
cat /etc/hosts
172.18.0.3      grafana.local.amazinglyabstract.it
172.18.0.3      my-zitadel.local.amazinglyabstract.it
172.18.0.3      frontend.local.amazinglyabstract.it
172.18.0.3      minio.local.amazinglyabstract.it
172.18.0.3      console-minio.local.amazinglyabstract.it
```

## Pulumi configuration

Finally!

By default, Pulumi uses the [cloud backend](https://www.pulumi.com/docs/iac/concepts/state-and-backends/#pulumi-cloud-backend), that's not what we want. This is where Pulumi is going to store the state.

Let's configure it to use the [local filesystem](https://www.pulumi.com/docs/iac/concepts/state-and-backends/#local-filesystem).

```bash
cd pulumi-zitadel
pulumi login --local
```

If we were starting from scratch we would also need to run `pulumi new` to create a new project. But we'll be using the code in `pulumi-zitadel/`

This project is configured to use a JWT token to authenticate with the Zitadel API. The token was already generated during the helm installation and stored in a secret. Let's get it:

```bash
kubectl get secret zitadel-admin-sa -o jsonpath='{.data.zitadel-admin-sa\.json}' | base64 -d > zitadel-admin-sa.json
```

We should be good to go. Let's take a look at what we are going to ask Pulumi to configure.

<iframe frameborder="0" scrolling="no" style="width:100%; height:810px;" allow="clipboard-write" src="https://emgithub.com/iframe.html?target=https%3A%2F%2Fgithub.com%2Fdriv%2Fzitadel-pulumi%2Fblob%2Fmain%2Fzitadel-pulumi%2Fmain.go%23L25-L59&style=a11y-light&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on&fetchFromJsDelivr=on"></iframe>

We are not only creating the Zitadel project, Grafana application and roles, but we are also able to create a Secret for Grafana to know its client ID.

<iframe frameborder="0" scrolling="no" style="width:100%; height:410px;" allow="clipboard-write" src="https://emgithub.com/iframe.html?target=https%3A%2F%2Fgithub.com%2Fdriv%2Fzitadel-pulumi%2Fblob%2Fmain%2Fzitadel-pulumi%2Fmain.go%23L61-L76&style=a11y-light&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on&fetchFromJsDelivr=on"></iframe>

Time to apply our CaC:

```bash
pulumi up
```

This will create a new stack and deploy the resources defined in `main.go`.

# Second iteration: Pulumi Kubernetes Operator

Running Pulumi locally is a good start, now we need some automation. We could use a CI/CD tool like GitHub Actions or GitLab CI but we want to try a [pull-based](https://thenewstack.io/push-vs-pull-in-gitops-is-there-really-a-difference/) approach.

As part of the cluster setup, we have already installed the [Pulumi Kubernetes Operator](https://github.com/pulumi/pulumi-kubernetes-operator) and [Minio](https://github.com/minio/minio). It's time to use them.

## Pulumi Backend

The local backend we configured in the first iteration, is not going to be accessible from the cluster, we need to move it. We need to migrate our state into Minio.

```bash
# We use the credentials defined during the helm installation
export AWS_ACCESS_KEY_ID=rootuser
export AWS_SECRET_ACCESS_KEY=rootpass123

pulumi stack export --show-secrets --file pulumi-export.json

pulumi login 's3://pulumi-state?endpoint=minio.local.amazinglyabstract.it&s3ForcePathStyle=true'

pulumi stack import --file pulumi-export.json

pulumi up # It shouldn't need to make any change

```

## Stack Manifest

It's time to tell our Pulumi Operator what we want to configure.

Among the CRDs the operator installs, we have [`Stack`](https://github.com/pulumi/pulumi-kubernetes-operator/blob/master/docs/stacks.md).

<iframe frameborder="0" scrolling="no" style="width:100%; height:1150px;" allow="clipboard-write" src="https://emgithub.com/iframe.html?target=https%3A%2F%2Fgithub.com%2Fdriv%2Fzitadel-pulumi%2Fblob%2Fmain%2Fzitadel-pulumi%2Fstack.yaml%23L44-L94&style=a11y-light&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on&fetchFromJsDelivr=on"></iframe>

The operator will create a `Workspace` based on the `Stack` we defined and it will periodically check the state of the repository and trigger an update if needed.

All the configuration is included in the `Stack` configuration. The only thing missing is permissions to create the secret for Grafana. We provide it through the `ServiceAccount` used by the workspace.

<iframe frameborder="0" scrolling="no" style="width:100%; height:560px;" allow="clipboard-write" src="https://emgithub.com/iframe.html?target=https%3A%2F%2Fgithub.com%2Fdriv%2Fzitadel-pulumi%2Fblob%2Fmain%2Fzitadel-pulumi%2Fstack.yaml%23L20-L42&style=a11y-light&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on&fetchFromJsDelivr=on"></iframe>

We can apply the `Stack`, `Roles` and `RoleBindings`:

```bash
kubectl apply -f zitadel-pulumi/stack.yaml
```

And that's all! We are ready to let the operator keep our configuration up to date.

You can keep an eye on the `Stack` and `Workspace` with your favourite tool (k9s, lens, etc.) or with `kubectl`.

```bash
$ kubectl get stack
NAME             LAST UPDATE   AGE   READY   RECONCILING       STALLED   PERMALINK
zitadel-pulumi   succeeded     8d    False   StackProcessing

$ kubectl get workspace
NAME             IMAGE   READY   ADDRESS
zitadel-pulumi           False
```

# Conclusion

I was pleasantly surprised by Pulumi per se. I loved being able to work with a language I am familiar with and use the IDE to its full potential. As the configuration grows, I think the benefits become more significant.

At least for Zitadel, you can see that the Pulumi package is just a conversion from Terraform, meaning that it does not take full advantage of the language features. It relies on untyped strings for configuration which makes it error-prone.

The Zitadel API is also not helpful since it's returning generic errors or even the wrong HTTP status code in some scenarios.

The operator is a great addition, but it's not fully mature yet. I've tried to use a self-contained image instead of getting the data from the repository, but it kept trying to install the dependencies that were already present.

There is also no clear way to fully define the backend configuration, forcing us to define environment variables in the `Stack` definition.

I wouldn’t use the operator in production yet; I’d stick with an external CI/CD tool for now. However, I hope this changes, as I'd love to avoid having to expose configuration credentials or APIs externally.
