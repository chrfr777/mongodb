# this script expects 2 environment variables
#    1. SQS_KEY_ID (preferably an IAM user with limited rights)
#    2. SQS_SECRET_KEY (accompanying secret key)
#    3. SQS_TASK_QUEUE (the queue to use)

import os
import platform

from boto.route53.connection import Route53Connection
from boto.route53.record import ResourceRecordSets

# your amazon keys
key = os.environ['R53_KEY_ID']
access = os.environ['R53_ACCESS_KEY']

NAME = os.environ['NAME']
HOSTED_ZONE_NAME = os.environ['HOSTED_ZONE_NAME']
HOSTED_ZONE_ID = os.environ['HOSTED_ZONE_ID']
hostname = platform.node()

if __name__ == '__main__':
    zones = {}
    value = ''
    route53 = Route53Connection(key, access)
    
    # get hosted zone for HOSTED_ZONE_NAME
    results = route53.get_hosted_zone(HOSTED_ZONE_ID)
    zone = results['GetHostedZoneResponse']['HostedZone']
    zone_id = zone['Id'].replace('/hostedzone/', '')
    zones[zone['Name']] = zone_id

    # first get the old value
    sets = route53.get_all_rrsets(zones[HOSTED_ZONE_NAME], None)
    for rset in sets:
        if rset.name == NAME % '.%s' % HOSTED_ZONE_NAME:
            value = rset.resource_records[0]

    # only change when necessary
    if value != hostname:
        # first delete old record
        changes = ResourceRecordSets(route53, zone_id)

        if value != '':
            change = changes.add_change("DELETE", NAME % '.%s' % HOSTED_ZONE_NAME, "CNAME", 60)
            change.add_value(value)

        # now, add ourselves as zuckerberg
        change = changes.add_change("CREATE", NAME % '.%s' % HOSTED_ZONE_NAME, "CNAME", 60)
        change.add_value(platform.node())

        changes.commit()
