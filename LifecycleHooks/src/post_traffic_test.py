import urllib3
import json
from aws_lambda_powertools import Logger
logger = Logger()

http = urllib3.PoolManager()
def lambda_handler(event, context):
    try:
        test_endpoint = event['hookDetails']['TestEndpoint']
        request = http.request("GET",test_endpoint)

        if request.status == 200:
            logger.info(f"Test traffic hook succeeded with staus {request.status}")
            return {"hookStatus": "SUCCEEDED"}
        else:
            logger.info(f"Test traffic hook failed with status {request.status}")
            return {"hookStatus": "FAILED"}
    except Exception as e:
        logger.error(f"Hook status failed processing with error: {e}")
