---
layout: post
title: "Dynamic programming - A real world application"
categories: Programming
tags: Algorithms Pattherns Performance
---
I've know and understood this algorithmic pattern for a few years already.
As with many of these beautiful and efficient solution, it's not always easy to find them in the wild.

# What is dynamic programming #

You can read the definition in [Wikipedia](https://en.wikipedia.org/wiki/Dynamic_programming). In essence it works by recursively splitting a problem into sub problems and reusing their solution.

## The classic example - Coin change ##

Let's say we have a currency which has coins of values 0.10, 0.25, 0.50, 1.00. Given a value 1.20 for example. What is the least amount of coins we can use to give the 1.20 change.

We can obvously brute force our way Ñq



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
