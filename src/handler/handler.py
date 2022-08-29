import boto3

def lambda_handler(event, context):
    receive_message()


def receive_message():
    sqs_client = boto3.client("sqs", region_name="eu-central-1")
    response = sqs_client.receive_message(
        QueueUrl="https://sqs.eu-central-1.amazonaws.com/062711863967/paultestsqs",
        MaxNumberOfMessages=1,
        WaitTimeSeconds=10,
    )

    print(f"Number of messages received: {len(response.get('Messages', []))}")

    for message in response.get("Messages", []):
        message_body = message["Body"]
        print(f"Message body: {json.loads(message_body)}")
        print(f"Receipt Handle: {message['ReceiptHandle']}")

receive_message()