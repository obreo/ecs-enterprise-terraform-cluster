import urllib3
import json
import logging

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

http = urllib3.PoolManager()

def lambda_handler(event, context):
    try:
        logger.info(f"Event received: {json.dumps(event)}")
        
        test_endpoint = event['hookDetails']['TestEndpoint']
        logger.info(f"Testing endpoint: {test_endpoint}")
        
        response = http.request("GET", test_endpoint, timeout=10.0)
        logger.info(f"Response status: {response.status}")
        
        if response.status == 200:
            logger.info("Test succeeded")
            return {"hookStatus": "SUCCEEDED"}
        else:
            logger.error(f"Test failed with status {response.status}")
            return {"hookStatus": "FAILED"}
            
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return {"hookStatus": "FAILED"}