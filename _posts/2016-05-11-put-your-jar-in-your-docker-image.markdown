---
layout: post
title: "How to put your jar in your Docker image"
categories: CD
tags: Maven Jenkins Docker
date: 2016-05-11 16:20:00+0200
---
The compilation has just finished and Maven shows us the message we all love:
{% highlight bash %}
[INFO] ------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------
{% endhighlight %}

**Great!** Now what?

How do we get the artifact we have just generated inside the Docker image we want to deliver?

We are going to analyse a few options:

- Move the artifact with the pipeline.
- Build the artifact inside the image.
- Publish the artifact to an external repository.

# Move the artifact with the pipeline. #

This is the method that I've seen more often used. It's probably the most straightforward but it can have some disadvantages.

## Copy the artifact

The premise is very simple and can be achieved with just one command.

`cp COMPILATION_WORKSPACE/target/app*.jar ${WORKSPACE}`

This is the simplest and most naive approach, and it can work pretty well until a new execution steps on the jar and we are not sure anymore which version of the jar we are putting inside our image. It can take a while to notice this problem and by the time we do, have generated multiple inconsistent images.

## Archive the artifact

We can tell Jenkins to archive the artifacts at the end of compilation and then get them using a specific build number or git commit id. This way we are sure we are picking the artifact from the correct job execution.

# Build the artifact inside the docker image

Using this strategy we can reduce the compilation and image creation to a single step.

If you are using maven to build the application, you can use a maven docker image to execute the build inside such image and even add git to download the source code.

The problem with this approach is that a lot of unnecessary things are going to remain inside the image. Also, the Dockerfile is going to be more complex.

This kind of images may be more suited to use in a development environment than as a final deliverable product.

# Publish the artifact to an external repository #

We can use some maven repository implementations like Artifactory or Nexus to store the jar after compilation and then let Docker retrieve it when the image is built.

To guarantee that the jar we build is available for the subsequent image creation and is not overwritten by another execution, the jar version has to include something like a build number. That way we can be sure that the jar we are retrieving is the one for this execution.

The problem with this approach is that we store many jars, one for each build. Let's not forget that these jars usually contain all the libraries needed for the application to work. So it would be necessary to implement some cleaning strategy to remove old jars.

# Conclusion

There may be even more ways to achieve the goal of getting the artifact/s that have just been generated inside the image we are going to use for testing and then production.

The important thing we have to take into account is that there should be no way of mixing the artifacts. The process has to guarantee us that the artifact inside our image is the one generated from a specific source code. The only way to guarantee this is to have a unique identifier for our artifacts. This does not mean that the name of the artifact has to change necessarily, we can change other factors, like the location.