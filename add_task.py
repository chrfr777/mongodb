# this script expects 2 environment variables
#    1. SQS_KEY_ID (preferably an IAM user with limited rights)
#    2. SQS_SECRET_KEY (accompanying secret key)
#    3. SQS_TASK_QUEUE (the queue to use)

import os
import sys

from boto.sqs.connection import SQSConnection
from boto.sqs.message import Message

import utils

# your amazon keys
key = os.environ['SQS_KEY_ID']
access = os.environ['SQS_ACCESS_KEY']
queue = os.environ['SQS_TASK_QUEUE']

if __name__ == '__main__':
    region_info = utils.get_region_info()
    sqs = SQSConnection(key, access, region=region_info)

    tasks = sqs.create_queue(queue)

    m = Message()
    m.set_body(sys.argv[1])
    tasks.write(m)
