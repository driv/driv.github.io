---
layout: post
title: "Jenkins Pipeline as Code test drive"
categories: devops
tags: Jenkins Pipeline-as-Code Gradle
date: 2016-05-05 16:20:00+0200
---
After having read that Jenkins 2 was out, I decided to give it a go and see what has changed and see what can we do with [Pipeline as Code](https://wiki.jenkins-ci.org/display/JENKINS/2.0+Pipeline+as+Code).

# Bootstrapping #

We'll be using Docker to bootstrap a Jenkins instance. At the moment the `2.0` tag is available.

{% highlight bash %}
JENKINS_ID=$(docker run -d -p 8080:8080 jenkins:2.0)
{% endhighlight %}

You can now go to `localhost:8080` and... surprise!
This is new. There is a default password that we have to get from a file inside the docker container.

{% highlight bash %}
docker cp $JENKINS_ID:/var/jenkins_home/secrets/initialAdminPassword .
cat initialAdminPassword
{% endhighlight %}

We can now enter the password and follow the wizard letting Jenkins install the suggested plug-ins.

Complete the admin user creation form and you can start playing with Jenkins.

# Pipeline configuration #

Create a new Item. We need a `Multibranch Pipeline` and call it whatever you want. I'll be using `jenkins_pipeline_as_code`.

In `Branch Sources` choose github, enter a github username and select a repository from the drop-down.
You can use mine (`driv/jenkins_pipeline_as_code`) or create a new Github repository.

## Jenkinsfile ##

Here is where we start using Pipeline as Code. We are going to create a new `Jenkinsfile` at the root of our git repository and push it.

For now, its content can be something like this.
{% highlight groovy %}
echo "The pipeline is working!"
{% endhighlight %}

## First build ##

Get to the job you've created (`jenkins_pipeline_as_code`), on the right you should see `Branch indexing`, click it and then `Run now`.

Jenkins should detect the branch master, see that it has a Jenkinsfile inside and execute the pipeline. If we check the console output of the execution, we should see something this:
{% highlight log %}
[Pipeline] echo
The pipeline is working!
[Pipeline] End of Pipeline
{% endhighlight %}

# Application #

We are going to build an extremely simple API based on the getting started example of Spring Boot. You can get the source from my [git repository](https://github.com/driv/jenkins_pipeline_as_code) inside the api folder.

## Compilation ##

As you can see from the source code, we have the gradle wrapper (gradlew). We are just going to ask Jenkins to execute it to build the application.

For that, we just have to change the `Jenkinsfile`. That is going to end up looking something like this:

{% highlight groovy %}
echo "Starting pipeline"

stage 'Checkout'

node {
	checkout scm
}

stage 'Compilation'

node {
	dir ('api'){
		sh './gradlew build'
		stash includes: 'build/libs/gs-spring-boot-0.1.0.jar', name: 'api-jar'
	}
}
{% endhighlight %}

This pipeline is defined as two stages. The first one just downloads the source code from the scm that we defined when we created the `Multibranch Job`. The second stage switches to the api folder and there executes the gradlew script to build the application, it also stashes the generated jar, that we could use in other stages of the pipeline.

After pushing it, we can tell Jenkins to execute the build again and it will pick up the new pipeline configuration.

# Conclusion #

We can see that with minimum configuration we can have a Jenkins instance running and building our application. Also thanks to the way we can define the pipeline, we can have it versioned together with the application.

That would be all for this test drive, but I'll explore other more complex scenarios in the future.