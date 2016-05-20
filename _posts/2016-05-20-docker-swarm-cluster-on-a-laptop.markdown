---
layout: post
title: "Docker swarm cluster on a laptop"
categories: provisioning
tags: Vagrant Ansible Docker "Docker swarm"
description: We are going to follow this [docker swarm tutorial](https://docs.docker.com/swarm/install-manual/), make it work on Virtualbox with Vagrant instead of AWS and script the configuration using Ansible.
date: 2016-05-20 11:20:00+0200
---
We are going to follow this [docker swarm tutorial](https://docs.docker.com/swarm/install-manual/), make it work on Virtualbox with Vagrant instead of AWS and script the configuration using Ansible.

You can find the final result on [this repository](https://github.com/driv/blog_docker-swarm-cluster-on-a-laptop).

Let's get started.

# Tools

I'm on a Ubuntu computer, so I this guide is going to be based on that.

## Virtualbox

Virtualbox can be installed with apt `apt install virtualbox`.

## Vagrant 1.8.1 

It can be installed using the package manager: `apt install vagrant`

## Ansible 2.2.0

The version 2.2.0 was not yet available on apt. The good thing is that it can be installed directly from the development repository using [pip](https://pypi.python.org/pypi/pip).

`sudo pip install git+git://github.com/ansible/ansible.git@devel`

## Redis 3.2.0

Yes, we are going to need Redis we'll see afterwards why. Luckily is extremely easy to install. You can follow [these steps](http://redis.io/topics/quickstart).

# Scripting the swarm creation

## Spin up the instances

Vagrant is going to create the 5 instances (1 Consul, 2 Managers, 2 Nodes).

{% highlight ruby %}
#Vagrantfile
Vagrant.configure(2) do |config|
	config.vm.box = "centos/7"
	config.ssh.insert_key = false
	instances_names = ["consul0", "manager0", "manager1", "node0", "node1"]

	instances_names.each do |name|
		config.vm.define name do |config|
			config.vm.network "private_network", type: "dhcp"
		end
	end

end
{% endhighlight %}

That is all we need to initialize the instances. We can do `vagrant up` and have 5 instances ready for us.

But that is obviously not enough, we are **not** going to install what we are missing manually.

## Install docker on all instances

### Enter the playbook!

{% highlight yml %}
{% raw %}
#playbook.yml
---
- hosts: all
  sudo: yes
  tasks:
    - name: Add docker yum repository
      yum_repository:
        name: docker
        description: docker repository
        baseurl: https://yum.dockerproject.org/repo/main/centos/$releasever/
        gpgcheck: yes
        gpgkey: https://yum.dockerproject.org/gpg
    - name: Install docker-engine
      yum:
        name: docker
    - name: Configure Docker options
      template:
        src: 'etc/sysconfig/docker.j2'
        dest: '/etc/sysconfig/docker'
        owner: 'root'
        group: 'root'
        mode: '0644'  
    - name: Start docker service
      service:
        name: docker
        state: started
{% endraw %}
{% endhighlight %}

What's happening here:

- The yum repository is added to the instances.
- The docker engine is installed.
- A template is copied to configure the docker daemon.
- The docker service is started

### What about Vagrant?

The Ansible playbook is ready to install docker but Vagrant still has no idea about it. Let's make it aware of this.

{% highlight ruby %}
#Vagrantfile
Vagrant.configure(2) do |config|

 #[...]

	config.vm.provision "ansible" do |ansible|
		ansible.verbose = "v"
		ansible.playbook = "playbook.yml"
	end

end
{% endhighlight %}

Vagrant is going to look for `playbook.yml` in the same directory where the `Vagrantfile` is located and execute it.

Now we are ready to let Ansible provision our instances. For that, `vagrant reload --provision`.

##Time to start the containers

Ansible allows us group instances to select on which instances a task should be executed. We can define the groups in the Vagrantfile and pass them to Ansible. This will be the last change we make to the Vagrantfile.

This is the final Vagrantfile:
{% highlight ruby %}
#Vagrantfile
Vagrant.require_version ">=1.7.0"

Vagrant.configure(2) do |config|
	config.vm.box = "centos/7"
	config.ssh.insert_key = false
	instances_names = ["consul0", "manager0", "manager1", "node0", "node1"]

	instances_names.each do |name|
		config.vm.define name do |config|
			config.vm.network "private_network", type: "dhcp"
		end
	end

	groups = {
		"group-managers" => [
			"manager0",
			"manager1"
		],
		"group-consuls" => ["consul0"],
		"group-nodes" => [
			"node0",
			"node1",
		]
	}

	config.vm.provision "ansible" do |ansible|
		ansible.verbose = "v"
		ansible.groups = groups
		ansible.playbook = "playbook.yml"
	end
end
{% endhighlight %}

As you can see we have defined 3 groups and we are passing them to Ansible. Now we are going to put these groups to use.

###Start the consul container.

{% highlight yml %}
{% raw %}
#playbook.yml
#[...]
- hosts: group-consuls
  tasks:
    - name: Start consul container
      shell: docker -H :2375 run -d -p 8500:8500 --name=consul progrium/consul -server -bootstrap
{% endraw %}
{% endhighlight %}

###Start the swarm managers.

{% highlight yml %}
{% raw %}
#playbook.yml
#[...]
- hosts: group-managers
  tasks:
    - name: Start swarm main container
      shell: docker -H :2375 run -d -p 4000:4000 swarm manage -H :4000 --replication --advertise {{ ansible_eth1.ipv4.address }}:4000 consul://{{ hostvars[groups['group-consuls'][0]].ansible_eth1.ipv4.address }}:8500
{% endraw %}
{% endhighlight %}

###Start the nodes.

{% highlight yml %}
{% raw %}
#playbook.yml
#[...]
- hosts: group-nodes
  tasks:
    - name: Start swarm node
      shell: docker -H :2375 run -d swarm join --advertise={{ ansible_eth1.ipv4.address }}:2375 consul://{{ hostvars['consul0'].ansible_eth1.ipv4.address }}:8500
{% endraw %}
{% endhighlight %}

##Redis
If you execute the provision right now is not going to work. You can find a perfect explanation in [this blog post](http://blog.wjlr.org.uk/2014/12/30/multi-machine-vagrant-ansible-gotcha.html).

We need 1 config file to tell Ansible to store the instances facts on Redis.

{% highlight bash %}
#ansible.cfg
[defaults]
fact_caching = redis
fact_caching_timeout = 86400
{% endhighlight %}

If you have done your [homework](#redis-320), you should have Redis already installed. We can start it with `redis-server` and leave it running.

Now we could complete the provisioning (`vagrant reload --provision`). Or even if we wanted, reload everything from scratch with `vagrant destroy; vagrant up`.

#Considerations

The playbook works but there are a few things that can be much improved and are not going to be covered in this post.

##Playbook structure.

Everything was put together in the same playbook and roles are not being used.

By using roles we could define a role for each group (manager, consul and node) and each of them could have the role docker.

##Idempotence

If you execute the provision more than once, you'll see that is going to fail because is going to try to run the containers again even if they are already running or if it succeeds, we'll see more than 1 container running on the instance.

There already is a [docker module](http://docs.ansible.com/ansible/docker_module.html) in Ansible, that can be used instead of `shell` as we used in our playbook and is going to make sure that the container is not already created and start it if it's stopped. The problem with this task is that it does not currently support passing parameter to the container execution.

##Variables

To register the manager and nodes in consul, we are retrieving the IP by scavenging its value from the facts of the `consul0` instance, it would be nicer to have a DNS in place and reference a host instead.

#Conclusion

Thanks to Vagrant and Ansible we are capable of reproducing and validating the orchestration of our environment on our development machine allowing faster iterations.