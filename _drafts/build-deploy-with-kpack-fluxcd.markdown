---
layout: post
title: "Build and CD from your Kubernetes cluster"
categories: Blog
tags: buildpacks kpack fluxcd kubernetes
---

# A tiny self-contained Continuous Build and Deployment from Kubernetes #

In this post we're going to be looking into how to put together a CI/CD pipeline with...
*Hold on, not CI/CD. There is no Integration, just Build. The D in CD is for Deployment, not Delivery.*

Let's put together a CB/CD pipeline with kpack and fluxcd.

## The Tools
We are going to use:
- fluxcd
- kpack
- A GitHub account
- A DockerHub account

We are going to need locally:
- [docker](https://docs.docker.com/engine/install/)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installing-with-a-package-manager) and [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [pack](https://buildpacks.io/docs/for-platform-operators/how-to/integrate-ci/pack/#pack-cli)
- git

### Cloud Native Buildpacks
Buildpack or Cloud Native Buildpack (CNB) is a CNCF project that allows us to generate container images from source code **without** Dockerfiles.

***Why? What's wrong with Dockerfiles?***

Dockerfiles are very flexible, but most application builds do not need this flexibility. They would probably benefit from a pre-defined build mechanism that just works.

It's hard to standardise images if every application defines their Dockerfile and it's even harder to maintain them when you need to change every Dockerfile to update packages and base images.

***How does buildpack do this?***

Buildpack uses a builder. The builder defines a Stack and Buildpacks. 

A Stack is comprised of 2 images: a build image and a run image.

The build get executed on the **build image** and multiple buildpacks get used depending on what is being built.

A buildpack can handle part of a build and/or include other buildpacks recursively, during the build each buildpack detects wether its needed in the build process. Each buildpack manages detection, cache and execution.

![Buildpacks build of a A Spring Boot appplication using gradle](/public/posts_assets/build-deploy-with-kpack-fluxcd/buildpack-java-build.svg)
<small>*Build of a Spring Boot appplication with Gradle*</small>

Once the build is done the **run image** is used as a base and each buildpack used provides a layer with the generated artifacts.

If you have `pack` installed locally you can see it in action by building the apps in the [example repo](https://github.com/driv/flux-image-updates). You don't need java nor golang installed, just `pack` and `docker`

{% highlight bash %}
# From the golang-apiserver directory
pack build my-golang-image --builder=paketobuildpacks/builder-jammy-base:latest
{% endhighlight %}
{% highlight bash %}
# From the java-apiserver directory
pack build my-java-image --builder=paketobuildpacks/builder-jammy-base:latest
{% endhighlight %}

You'll find yourself with 2 runnable images:
{% highlight bash %}
docker run -p 8080:8080 my-java-image
docker run -p 4444:4444 my-golang-image
{% endhighlight %}

One important feature is that it allows rebasing images. This means that it can swap the run image without rebuilding the source code. Perfect for fixing vulnerabilities.


#### Kpack implements Buildpacks

Kpack is Buildpacks for Kubernetes. It will allow us to define Stacks, Builders and Images as Kubernetes resources.
It can monitor a git repository and trigger a build on changes. It also allows to trigger rebases when the builder changes.

### FluxCD implements GitOps
We can use FluxCD to bootstrap and configure our Cluster but not only that.

One interesting FluxCD feature is it's capacity to automatically update images in manifests. This is normally used to update the application Deployments but its flexibility enables updating images used in any kind of resource, like kpack `ClusterStack`.

ImagePolicy for a Deployment

{% highlight yaml %}

[...]
    containers:
    - name: java-api
        image: driv/buildpack-playground-java-api:b26.20240527.063829 # {"$imagepolicy": "flux-system:buildpack-playground-java-api"}
[...]

{% endhighlight %}

Even if FluxCD is not aware of the `ClusterStack` resource, it can automatically upgrade the image.

{% highlight yaml %}

apiVersion: kpack.io/v1alpha2
kind: ClusterStack
metadata:
  name: base
spec:
  id: "io.buildpacks.stacks.jammy"
  buildImage:
    image: "paketobuildpacks/build-jammy-base:0.1.115" # {"$imagepolicy": "flux-system:build-jammy-base"}
  runImage:
    image: "paketobuildpacks/run-jammy-base:0.1.115" # {"$imagepolicy": "flux-system:run-jammy-base"}

{% endhighlight %}

## Try it yourself

You can fork [this repo](https://github.com/driv/flux-image-updates) and try it yourself.