import os, subprocess

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

    m = tasks.read()
    while m != None:
        body = m.get_body()
        exit = subprocess.call(["/usr/bin/mongo",
                "--quiet", "--eval", body])

        tasks.delete_message(m)

        m = tasks.read()
