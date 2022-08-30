import boto3

def lambda_handler(event, context):
    string = "Successful upload"
    encoded_string = string.encode("utf-8")

    bucket_name = "fileuploadtestlf10"
    file_name = event["body"] + ".txt"
    s3_path = "logs/upload_log/" + file_name

    s3 = boto3.resource("s3")
    s3.Bucket(bucket_name).put_object(Key=s3_path, Body=encoded_string)
