---
layout: post
title: "No clicks continuous delivery"
categories: CD
tags: Jenkins Docker AWS Cloudformation
---
UIs are the enemy of automation, they are hard to test, they make configuration tedious and hard to replicate, we have to avoid them at all costs.

So today, as an excercise, we are going to see how far we can get in completing a full development cycle (from empty git repository to software deployed) without interacting with UIs.

# The application #
We'll be implementing a web TODO list (how original!).
The application is comprised of:
- Static front-end
- Java rest API
- Database

# Infrastructure #
## Development ##
I'm currently using an ubuntu machine.

## Contiuous Integration ##
We are going to be using Jenkins 2 deployed on AWS and hosting the code on Github.

## Deployment ##
On AWS with docker. //TODO