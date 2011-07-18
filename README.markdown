= MongDB (RDS-style) =

MongoDB is drawing crowds, lately, some even dare to call it the new MySQL. We didn't work it yet, although we investigated its use on GeoSpatial systems already a while ago.

Usabilla, our latest partner, and one of the Amsterdam's hottest startups wants one. One of the reasons they 'want one' is that it promises to help them fight the monkey that wrecked serious havoc on my wedding day. So, we have to build a MongoDB 'thing' on Amazon AWS giving us
- high availability
- and scalability
If do not have the patience to continue to read, but want to get down to it immediately, go get our stuff at github.

== MongDB ==

We want to run a MongDB replica set. In short it gives you a distributed database, with one 'primary' and hopefully one or more 'secondaries' that can take over when the system decides that is necessary. One obvious example of electing a new master is failure of the old one. Another obvious one is for maintenance, at least when it is easy to force these reconfigurations.

The smallest MongoDB replica set that is recommended has one primary, one secondary and one arbiter. The arbiter doesn't do much, but helps in electing new primaries when necessary. We don't want to rely on one arbiter, so we'll use two. (This is not that expensive, because we can run them on t1.micro instances.)

The idea is to build two different types of instances
- regular replica set member (primary or secondary) holding data
- arbiters without data
Once the replica set is initiated, has at least one primary, the members have to be able to (de)register itself. A member will join the replica set automatically. The arbiter will do nothing but vote. A new member will either do a full sync, or an incremental sync depending on the availability of backups. (The MongoDB data and log is stored on a separate EBS volume.)

== Addressability (Route53) ==

Of course we want to be able to talk to this replica set. Most of the difficult work of talking to a set of instances has already been taken care of by MongoDB. We only need to find one available member, doesn't matter which.

Each regular member periodically checks if it is primary, and if so instructs Route53 to make zuckerberg.usabilla.com point to its own public DNS, if it didn't already. This way, the entry point of the replica set will most be valid most of the time. Only when the primary dies a sudden death, will it take around a minute or two for the entry point to be valid again.

== Initiation ==

Our MongoDB replica set has two AutoScaling groups, one for regular set member and the other for arbiters. We need to start carefully, because we have bootstrap the replica set. We launch the first two regular instances. One of these instances will be the primary by running

<code>mongo --eval "rs.initiate()"</code>

If the initiation is done, this instance will tell Route53 to point zuckerberg.usabilla.com to its own public DNS name. The moment the DNS is updated, and the domain resolves properly we'll tell the second instance to join the cluster

<code>mongo zuckerberg.usabilla.com --eval "rs.add(\"`hostname`:27017\")"</code>

== Backups ==

Now that we have a replica set behind zuckerberg.usabilla.com, we have to talk about backups. The primary already has a responsibility, it takes care of the addressability of the set. The backups will be delegated to the secondaries, which is the logical thing to do.

We normally use snapshots as backups, administering the expiration with SimpleDB. This is perfect for disaster recovery (DR) but we also need to know the most recent snapshot. We added a timestamp to the item, and can now query for the most recent snapshot.

If a regular member launches, it first checks the availability of snapshots. If there are snapshots (the replica set exists) it creates a new volume from that snapshot. And tells the replica set to add it to the set.

== Conclusion ==

There are a couple of small things we would like to do, namely
- automatic removal of stale members
- CloudWatch monitoring of member
- and CloudWatch monitoring of the replica set
But, in the meantime, we have probably the coolest MongoDB replica set in Amazon AWS!! It is very resilient, and we'll survive Chaos Monkeys easily, even those that visit on nice spring days. Of course we use Availability Zones, for extra durability.

An added bonus is that it is extremely easy to upgrade the entire system. If we want to do an upgrade, of compatible MongoDB versions, we only have to change the AutoScaling, terminate the instances one by one. Our MongoDB RDS will take care of the rest.

<code>
as-create-launch-config mongodb-zuckerberg-usabilla-com-lc-7 \
        --image-id ami-fd915694 \
        --instance-type m1.large \
        --group mongodb
as-update-auto-scaling-group mongodb-zuckerberg-usabilla-com-as-group-1 \
    	--launch-configuration mongodb-zuckerberg-usabilla-com-lc-7 \
        --min-size 2 \
        --max-size 2

as-terminate-instance-in-auto-scaling-group i-55f03d34 -D
as-terminate-instance-in-auto-scaling-group i-e16aaa80 -D
</code>

