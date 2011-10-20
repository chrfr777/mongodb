# MongoDB on AWS (RDS-Style)

<img src="http://byrene.net/wp-content/uploads/2011/04/ChaosMonkey-e1302266059582.jpg" width="256px" align="left" /> [MongoDB](http://www.mongodb.org/) is drawing crowds, lately. Some even dare to call [it the new MySQL](http://www.thenetworkadministrator.com/MongoDB_MySQL.htm). We didn't work with it yet, although we investigated its use on GeoSpatial systems already [a while ago](http://www.9apps.net/blog/2010/5/11/where-to-put-my-pois.html).

[Usabilla](http://www.usabilla.com/), our latest partner, and one of  [Amsterdam's hottest startups](http://www.sfgate.com/cgi-bin/article.cgi?f=/g/a/2011/06/22/prweb8583904.DTL) wants one. Apart from being fun, one of the reasons they 'want one' is that it promises to help them fight [the monkey](http://aws.amazon.com/message/65648/) that wrecked serious havoc on my wedding day. So, we have to build a MongoDB 'thing' on Amazon AWS giving us

* high availability, and
* scalability

MongoDB will help Usabilla deal with huge key/value style datasets when they will start collecting feedback from live events. It is also a good fit because the team can continue to practice their Javascript skills.

![MongoDB on AWS Architecture](https://docs.google.com/drawings/pub?id=1xRIj3E15t3Id7nZTHWGQ7ehhqFdYZ9DnRPNXH82DRKk&w=513&h=436)

If you do not have the patience to continue to read, but want to get down to it immediately, go get [our stuff at github](https://github.com/9apps/mongodb). We installed everything on Ubuntu, you can see our full install script in the repository. This is how to easily install the latest MongoDB

	echo "deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen" \
			>> /etc/apt/sources.list	
	apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10
	apt-get update && apt-get install mongodb-10gen

If you want to go to MongoDB 2.0 you can download the Linux 64bit binaries, and install them

	wget http://fastdl.mongodb.org/linux/mongodb-linux-x86_64-2.0.0.tgz
	tar xzvf mongodb-linux-x86_64-2.0.0.tgz
	cp mongodb-linux-x86_64-2.0.0/bin/* /usr/bin

## MongoDB

We want to run a [MongoDB replica set](http://www.mongodb.org/display/DOCS/Replica+Sets). In short it gives you a distributed database, with one 'primary' and hopefully one or more 'secondaries' that can take over when the system decides that it is necessary. One obvious example of electing a new primary is failure of the old one. Another obvious one is for maintenance, at least when it is easy to force these reconfigurations.

The smallest MongoDB replica set that is recommended has one primary, one secondary, and one arbiter. The arbiter doesn't do much, but helps in electing new primaries when necessary. We don't want to rely on one arbiter, so we'll use two. (This is not that expensive, because we can run them on t1.micro instances.)

The idea is to build two different types of instances, but based on one image

1. regular replica set member (primary or secondary), holding data
2. arbiters, without data

We will run the arbiters on Micro instances. We will use user-data upon launch to designate the purpose of the instance.

Once the replica set is initiated, the members have to be able to (de)register itself. A member will join the replica set automatically. The arbiter will do nothing but vote. A new member will either do a full sync, or an incremental sync depending on the availability of backups. (The MongoDB data and log is stored on a separate [EBS](http://aws.amazon.com/ebs/) volume.)

## Addressability (Route53)

Of course we want to be able to talk to this replica set. Most of the difficult work of talking to a set of instances has already been taken care of by MongoDB. We only need to find one available member, doesn't matter which.

Each regular member periodically checks if it is primary, and if so instructs [Route53](http://aws.amazon.com/route53/) to make mongodb.usabilla.com point to its own public DNS, if it didn't already. This way, the entry point of the replica set will most be valid most of the time. Only when the primary dies a sudden death, will it take around a minute or two for the entry point to be valid again.

## Initiation

Our MongoDB replica set has two AutoScaling groups, one for regular set member and the other for arbiters. You don't need AutoScaling, you can also build a Replica Set with independent instances. We need to start carefully, because we have bootstrap the replica set. We launch the first two regular instances. We have to launch them one at a time.

To start a new Replica Set you first have to pick a name. Launch a large instance from the latest AMI with the following user-data

	{
		"name"			:	"winklevoss",
		"size"			:	100,
		"source"		:	"snap-78ee631b",
		"role"			:	"active",
	}

This will create a replica set, with a size of 100GB from the snapshot. You can find this replica set by going to http://winklevoss.usabilla.com:28017/, but you have to give it some time to add the record to Route53, etc.

If you visit http://winklevoss.usabilla.com:28017/_replSet and you see one active member with state Primary you are ready to continue. First we want to add the arbiters. This is easy, and quicker, because they don't do very much. Launch 2 micro instances from the same AMI as before, and give them the following user-data

	{
		"name"			:	"winklevoss",
		"role"			:	"arbiter",
	}

Go back to the winklevoss.usabilla.com replica set page, and wait until you have 1 primary, and 2 arbiters. Now we are ready to take the last step, adding a secondary. At this moment the current replica set doesn't have a backup, so we have to do a full sync. Launch a large instance, with the same AMI, and almost the same user-data as the first

	{
		"name"			:	"winklevoss",
		"size"			:	100,
		"source"			:	"",
		"role"				:	"active",
	}

## Backups

Now that we have a replica set behind mongodb.usabilla.com, we have to talk about backups. The primary already has a responsibility, it takes care of the addressability of the set. The backups will be delegated to the secondaries, which is the logical thing to do.

We normally [use snapshots as backups](https://github.com/9apps/programming-amazon-ec2), administering the expiration with SimpleDB. This is perfect for disaster recovery (DR) but we also need to know the most recent snapshot. We added a timestamp to the item, and can now query for the most recent snapshot.

If a regular member launches, it first checks the availability of snapshots. If there are snapshots (the replica set exists) it creates a new volume from that snapshot. And tells the replica set to add it to the set.

## Conclusion

There are a couple of small things we would like to do, namely

* automatic removal of stale members
* [CloudWatch](http://aws.amazon.com/cloudwatch/) monitoring of member
* and CloudWatch monitoring of the replica set

But, in the meantime, we have probably the coolest MongoDB replica set in Amazon AWS!! It is very resilient, and we'll survive Chaos Monkeys easily, even those that visit on nice spring days. Of course we use Availability Zones, for extra durability.

An added bonus is that it is extremely easy to upgrade the entire system. If we want to do an upgrade, of compatible MongoDB versions, we only have to change the AutoScaling, terminate the instances one by one. Our MongoDB RDS will take care of the rest.

	userdata='{
			"name"			:	"winklevoss",
			"size"			:	100,
			"source"			:	"",
			"role"				:	"active",
		}'
	as-create-launch-config mongodb-mongodb-usabilla-com-lc-7 \
			--image-id ami-fd915694 \
			--instance-type m1.large \
			--user-data ${userdata} \
			--group mongodb

	as-update-auto-scaling-group mongodb-mongodb-usabilla-com-as-group-1 \
			--launch-configuration mongodb-mongodb-usabilla-com-lc-7 \
			--min-size 2 \
			--max-size 2

	as-terminate-instance-in-auto-scaling-group i-55f03d34 -D
	as-terminate-instance-in-auto-scaling-group i-e16aaa80 -D
