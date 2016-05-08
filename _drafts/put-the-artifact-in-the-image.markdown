---
layout: post
title: "How to put your jar in your Docker image"
categories: CD
tags: Maven Jenkins Docker
---
The compilation has just finished and Maven shows us the message we all love:
{% highlight bash %}
[INFO] ------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------
{% endhighlight %}

**Great!** Now what?

How do we get the artifact we have just generated inside the Docker image we want to deliver?

We are going to analyze a few options:

- Move the artifact with your pipeline.
- Docker build the artifact inside the image.
- Publish the artifact and download it with Docker.