from boto.ec2.regioninfo import RegionInfo
import json, urllib2

def get_region_info():
  try:
    url = "http://169.254.169.254/latest/meta-data/"

    instance_id = urllib2.urlopen(url + "instance-id").read()
    zone = urllib2.urlopen(url + "placement/availability-zone").read()

    region = zone[:-1]
    region_info = RegionInfo(name=region, endpoint="sqs.{0}.amazonaws.com".format(region))
    return region_info

  except Exception as e:
    print e
    exit( "We couldn't get the current region...")

