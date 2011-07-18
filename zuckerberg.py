import platform

from boto.route53.connection import Route53Connection
from boto.route53.record import ResourceRecordSets

# your amazon keys
key = ''
access = ''

# some defaults
USABILLA_MONGODB_ZONE_NAME = 'usabilla.com.'
hostname = platform.node()

if __name__ == '__main__':
    zones = {}
    value = ''
    route53 = Route53Connection(key, access)
    
    # get hosted zone for USABILLA_MONGODB_ZONE_NAME
    results = route53.get_hosted_zone('ZH8OQI4H8I42P')
    zone = results['GetHostedZoneResponse']['HostedZone']
    zone_id = zone['Id'].replace('/hostedzone/', '')
    zones[zone['Name']] = zone_id

    # first get the old value
    sets = route53.get_all_rrsets(zones[USABILLA_MONGODB_ZONE_NAME], None)
    for rset in sets:
        if rset.name == 'zuckerberg.%s' % USABILLA_MONGODB_ZONE_NAME:
            value = rset.resource_records[0]

    # only change when necessary
    if value != hostname:
        # first delete old record
        changes = ResourceRecordSets(route53, zone_id)

        if value != '':
            change = changes.add_change("DELETE", 'zuckerberg.%s' % USABILLA_MONGODB_ZONE_NAME, "CNAME", 60)
            change.add_value(value)

        # now, add ourselves as zuckerberg
        change = changes.add_change("CREATE", 'zuckerberg.%s' % USABILLA_MONGODB_ZONE_NAME, "CNAME", 60)
        change.add_value(platform.node())

        changes.commit()
