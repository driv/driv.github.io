---
layout: post
title: "DevOps - The value in Value Stream Mapping"
categories: DevOps
tags: DevOps Lean Process
---

DevOps is everywhere, everyone is claiming that it makes you go faster so and you decided that you are ready for it. What's the next step?

Should you learn about Docker? Kubernetes? Continuous deployment?

As we all are a bit geeky with the technical side of the software development process, we can forget that software engineering is not only about cool tools and sleek programming languages. If we want to go faster, we need to take a look at our process.

Since having a new process from scratch is normally not feasible in a company that has to keep delivering, we'll need to evolve our current one. But before being able to improve it, we have to get to know it. And this is where Value Stream Mapping comes into play.

Considering the insight it can give us, it's quite a simple tool.

# What is it?

The idea behind Value Stream Mapping is to show the whole value stream from raw materials (change requests) to value being delivered (feature being used by the client) to customers. Take down the wall of departments/teams and show the process as a whole.

At the end of the process, we should have a better idea of which activities comprise it, which of these are generating value and which are not, which we can get rid of, the waste being generated, and where your changes come from. The changes part may seem obvious, requirements should generate changes, but you'll find out that there are other sources, like bugs, changes in infrastructure, etc.

This high-level view should allow for optimization of the process as a whole instead of local optimizations.

# What are we mapping?

It's important to decide from the beginning, which are the boundaries of the process we are mapping. The wider the better, but we can't map the whole company.
If our client is the one deciding which features should be developed, we should probably start from the first client request for a feature, not from the formal approval of the feature. Remember, we are streaming value from the customer perspective, it starts and ends with the client, whoever that might be.

# Bring everyone in the room

This can prove out to be the hardest part.
As the name says, DevOps is about bringing development and operations together, joining the whole development "chain". Which makes it kind of a no-brainer to have both teams (Or at least part of both teams) participate in the activity but that's not enough.

But the story does not end there, while operations might be at the end of the chain, development is almost never at the beginning. We have to invite more people to the party.

### Who else? Everyone.

 * Testers? They should be part of development anyway. 
 * Product owners? Totally.
 * Marketing? Sure, in many cases they are the ones coming up with the features in the first place.
 * Sales? You know the answer. Who knows the client better than sales.

Anyone involved in any way with the development process should be there.

Don't rely on what you know about the process, the process documentation or what someone else says. Have the people dealing with an activity on a day to day basis describe how things really are.

### The room 

It would be good to have a big room for 2 reasons, we need to accommodate everyone and we need to put our process down on whiteboards or paper attached to the walls. Also, we might need this room to be available and untouched for a few days.

![Value-stream-mapping-on-walls](/public/posts_assets/value-stream-mapping/value-stream-on-wall.jpg){:width="50%"}

# The steps

## Define what is being mapped

Everyone should have a clear understanding of what is going to be included in the map and what is out of scope.
We could be mapping more than one value-stream at the same time, this makes sense when these streams share multiple steps. e.g. features and security patches might originate from completely different actors and needs, but they probably share some of the steps to get to production.

## Make a list

Let everyone mention the steps of the process in order. After this we can focus on grouping them to reduce the granularity of our map, we should end up with around 10 steps.

![listLeft](/public/posts_assets/value-stream-mapping/listLeft.png){:width="50%"}![listRight](/public/posts_assets/value-stream-mapping/listRight.png){:width="50%"}

<!-- List from the images

- Client expresses the need for a new feature
- Product owner writes a new story for the feature
- The story gets approved to be developed
- The story gets triaged by the architecture team.
- Dev team puts the story in the sprint backlog
- Dev works on developing the feature
- Dev tests the feature in the development environment
- Fix detected issues
- Informal demo with PO
- Create unit tests
- Open pull request to merge to master
- Code gets reviewed
- Fix review findings
- Request deployment in the testing environment
- Request testing by QA
- QA generates manual tests for the application
- QA reviews manual tests with PO
- PO approves tests
- QA executes tests and reports findings
- QA and DEV look for errors' causes
- QA signoff
- Request for deployment to production
- prod deployment approval
- prod deployment
- OPS monitors the application status
- OPS report deployment issues
- OPS and DEV fixing deployment issues.

-->

This list is just a first iteration, it does not have to be 100% complete.

## Activities/Functions

There's certain basic information we should have about each of the activities. 

- **Owner:** it can be a team or a person, if it's neither, you might need to split the activity into smaller ones, there should be no handover in an activity.
- **Process time (PT):** the amount of time someone is actively working on this activity.
- **Lead time (LD):** total time it takes to complete the activity since all activities it depends on are completed.
- **Queue:** how many of these activities are normally waiting to be processed by the owner.
- **Cycle efficiency:** `PT/LD = CE`
- **Complete and accurate (C&A):** percentage of times the **input** of the activity is errors free.

None of these measures has to be terribly accurate, just let people think about their average daily activity.

## Model the activities dependencies

From **Right to Left** which means that we start from the customer, put down every activity being done and what feeds this activity. This will help us focus on which activities need to be completed before we can continue.

## Map the information flow

We have value going from left to right, but at the same time, we have information flowing in our process. You can map it by thinking about which systems your process relies on, Jira, GitHub, email? This is not valuable to the client per se, but it's what makes the process work.

## Colors

- <span style="color:black">**black to report the current situation.**</span>

We should be careful not to base our reporting of the current situation on documentation but on the report of the people doing the activities on a day to day basis. We want the real picture.
- <span style="color:red">**red to report what is wrong in the current situation.**</span>

Take into account that we have to look at issues that impact the whole flow, we are not interested in local inefficiencies. This step is not about blaming, is not about finding solutions, we are still **reporting**. The main thing we are looking for here is waste.
- <span style="color:green">**green to propose changes.**</span>

Now it's the time to get creative and to propose new solutions for current issues.
Same as before we have to improve the whole flow, even if sometimes that means making certain activities slower.

![Activity](/public/posts_assets/value-stream-mapping/activity.png)

# What is waste
In [this](https://www.amazon.com/Implementing-Lean-Software-Development-Concept/dp/0321437381) great book, waste from [lean manufacturing](https://en.wikipedia.org/wiki/Lean_manufacturing#Types_of_waste) is matched into 7 categories for software development.

1. **Partially done work:**
Everything that is in some stage different than running in production fits in this category. Unmerged code sitting on a branch, "closed" features waiting to be tested, requirements waiting for developers to be available, etc.
2. **Extra features:**
Any feature that the client is not going to use fits in this category. That's where small iterations can help us see that something is not being used before we keep refining it.
3. **Relearning:**
This happens when access to information is not easy. From testers having to guess how the system should work to developers reverse engineering an undocumented API that was developed in-house.
4. **Handoff:**
Any step of the process where tasks are being handed off to another person/team. In this situation, some tacit knowledge gets lost, making it much harder for the person responsible to continue the job.
5. **Task switching:**
We all know this one, it is extremely hard to focus when we are forced to juggle multiple tasks at the same time.
6. **Delays:**
Any step of the process where work is waiting for something and no progress is being done.
7. **Defects:**
Every time work has to flow backwards, to get reworked we have a defect. It does not matter in which stage we are.

## Some examples

Requirements churn, we are writing requirements too early and when things get implemented, they are not useful anymore. It can be caused by long release cycles, requirements might have been correct, but when the time came to release they were out of date. A long release cycle that is put in place to consolidate effort and reduce waste ends up achieving the exact opposite.

Integration issues, every time we try to integrate our code there are failures and we have to fix things, this can be caused by delayed merges and lack of integration testing.

Many defects found in the acceptance test stage. We should have mechanisms in place to find defects earlier.

Redundant or unnecessary steps. Sometimes getting rid of a whole step is the way to go.

# What to do next

Try to come up with a new value stream map that could be achieved in the next 3-6 months. Don't try to fix the whole process at once.

This should guide the organization in which areas the changes should be made.

# Sources
[This talk from Marcus Robinson - Marcus Robinson - How we used Value Stream Mapping to accelerate DevOps adoption](https://www.youtube.com/watch?v=OXMdSe1)
Implementing Lean Software Development: From Concept to Cash - Chapter 04


