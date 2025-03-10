---
layout: post
title: "Keycloak OIDC - Declarative Configuration on Kubernetes with Crossplane"
categories: Infrastructure Kubernetes
tags: Keycloak OIDC Kubernetes "Operator" Crossplane
date:	10/03/2025 08:00:00+0000
---
<!-- markdownlint-disable MD033 MD025 -->
Keycloak is many things, but simple and friendly aren't among them. Another major issue is the reliance on the UI in most configuration guides—*Not good, not good*.

Let's try to bring some clarity by putting things down in a declarative configuration. This is not a Keycloak guide, we'll only touch on some simple concepts.

Grafana is going to be our Guinea pig.

You can find all the code in this repository: [driv/keycloak-configuration](https://github.com/driv/keycloak-configuration)

# The TOOLS

## The Operator

You might be happy to hear that Keycloak has an [official Kubernetes operator](https://www.keycloak.org/operator/installation). Which, according to Operator Hub, has [capability level](https://sdk.operatorframework.io/docs/overview/operator-capabilities/) `IV`. If you've tried using it you know that's not true. Level `I` is defined as *"Automated application provisioning and configuration management"* which this operator does not fully cover.

But, it can provide us with an instance to build on.

<iframe id="keycloak-instance-definition" frameborder="0" scrolling="no" style="width:100%; height:730px;" allow="clipboard-write" src="https://emgithub.com/iframe.html?target=https%3A%2F%2Fgithub.com%2Fdriv%2Fkeycloak-configuration%2Fblob%2Fmain%2Fkeycloak-instance%2Fkeycloak-instance.yaml%23L1-L30&style=a11y-light&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on"></iframe>

Most things are self-explanatory.

`bootstrapAdmin` uses a secret to initialize both a user and a service. We'll use the `user` and Crossplane will use the `service`.

We must enable `backchannelDynamic` to allow Grafana to talk to Keycloak through the internal Kubernetes Service.

## Terraform and Crossplane

***Wait, what!?***

Since the Operator falls short, we need an alternative. Luckily Terraform has what we need and more.

Don't worry, we are **not** going to be using Terraform directly! We don't want to lose the reconciliation capabilities of Kubernetes. We'll be using it through this great [Crossplane Provider](https://marketplace.upbound.io/providers/crossplane-contrib/provider-keycloak/v1.11.0).

# Keycloak Concepts and Configuration

Independently of how we are configuring our authentication, there are a few things we need on the Keycloak side.

## Realm

This is how Keycloak groups resources. Each realm has its clients (applications), users, groups, etc. It's recommended not to use the master realm, but to reserve it to create other realms.

## Client

In this case Grafana.

With OIDC the client performs 2 tasks:

- Receives a jwt token from Keycloak and validates it.
- Retrieves the userinfo from Keycloak using the received token.

The second step is not always necessary, we could include all the information needed in the token.

### Scopes

When defining what user information the client has access to we define scopes. e.g. `name`, `email`, etc.

One scope we are particularly interested in is `roles` which unfortunately is not part of the OIDC definition and not part of the default data returned by Keycloak in the token or the userinfo endpoint.

To fix this, we need to define a mapper.

### Mapper

This is an important and not intuitive part of the configuration. We need to tell Keycloak to include the user roles in the userinfo data so Grafana can access it. We could do this as a global configuration, mapping any role into the token or userinfo, or per client.

# Crossplane

## Provider Installation and Configuration

Of course, the Crossplane provider is installed fully declaratively. You can check the [manifest](https://github.com/driv/keycloak-configuration/blob/main/keycloak-provisioning/provider-keycloak-admin.yaml).

The only thing to take into consideration is that the `client_id` and `secret` have to match what we defined in the [instance configuration secret](#keycloak-instance-definition), I've not been able to find a simple way to reuse those values.

## Keycloak Configuration

The whole configuration can be found in this [manifest](https://github.com/driv/keycloak-configuration/blob/main/keycloak-provisioning/keycloak-client-config.yaml).

![Resource Definition](/public/posts_assets/keycloak-kubernetes-configuration/grafana-provisioning-resources.svg)
<small>*Keycloak Configuration Resources*</small>

We'll go over the interesting parts.

### Client Definition

You can reference resources so you don't have to know their IDs to target them in the configuration.
<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fdriv%2Fkeycloak-configuration%2Fblob%2Fmain%2Fkeycloak-provisioning%2Fkeycloak-client-config.yaml%23L30-L36&style=a11y-light&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on&fetchFromJsDelivr=on"></script>

If you are familiar with Terraform, you know that resources have outputs and we can use their values in other resources. With `writeConnectionSecretToRef` we can store the autogenerated client secret in a Kubernetes `Secret` and make it available to Grafana.

### Mapper Definition

As we've mentioned before, we have to configure Keycloak to include the roles somewhere. We could have used a mapper at the realm level to include all the roles our user has assigned, but the Provider does not currently support it, so we'll do it for the Client we just defined.

<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fdriv%2Fkeycloak-configuration%2Fblob%2Fmain%2Fkeycloak-provisioning%2Fkeycloak-client-config.yaml%23L113-L137&style=a11y-light&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on&fetchFromJsDelivr=on"></script>

We need to specify the type of mapper and the protocol it applies to:

{% highlight yaml %}

    protocol: "openid-connect"
    protocolMapper: "oidc-usermodel-client-role-mapper"

{% endhighlight %}

And we also need to define where to include it (userinfo) and how:

{% highlight json %}

    "userinfo.token.claim" : "true"
    "claim.name" : "resource_access.${client_id}.roles"

{% endhighlight %}

This will result in the roles being included in the `/userinfo` response this way:

{% highlight json %}

    "resource_access": {
        "grafana": {
            "roles": ["admin", "editor"]
        }
    }

{% endhighlight %}

### Users, group and role-mapping

I've not generated manifests for these resources, but it should be trivial to manually create them. To be able to test the configuration we are going to need one user with one of the roles created for the Grafana client (admin, editor, viewer).

# Grafana

Grafana configuration is almost default apart from auth:

<script src="https://emgithub.com/embed-v2.js?target=https%3A%2F%2Fgithub.com%2Fdriv%2Fkeycloak-configuration%2Fblob%2Fmain%2Fgrafana%2Fgrafana-values.yaml%23L12-L29&style=a11y-light&type=code&showBorder=on&showLineNumbers=on&showFileMeta=on&showFullPath=on&showCopy=on&fetchFromJsDelivr=on"></script>

- `auth_url` is where the user is going to get redirected to for sign-in
- `token_url` is the Keycloak API endpoint used to renew the token
- `api_url` is where Grafana will retrieve the roles from
- `role_attribute_path` uses [JMESPath](https://jmespath.org/) to extract the role information and map it to a Grafana role.

# Conclusion

Despite having to use multiple different tools we were able to achieve a declarative configuration for a Client on Keycloak. I'm surprised that Keycloak does not provide a simpler mechanism, since `auth(z|n)` seems to me an area that would benefit from a reviewable versionable and continuously reconciled configuration.

## Considerations

This code is just a PoC, definitely not suited for production. Secrets should be handled with an external tool.
