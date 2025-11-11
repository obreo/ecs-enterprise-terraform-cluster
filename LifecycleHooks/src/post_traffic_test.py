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
        
        # Validate event structure
        if 'hookDetails' not in event:
            logger.error("hookDetails not found in event")
            return {
                "hookStatus": "FAILED",
                "reason": "hookDetails missing from event"
            }
        
        if 'TestEndpoint' not in event['hookDetails']:
            logger.error("TestEndpoint not found in hookDetails")
            return {
                "hookStatus": "FAILED",
                "reason": "TestEndpoint missing from hookDetails"
            }
        
        test_endpoint = event['hookDetails']['TestEndpoint']
        logger.info(f"Testing endpoint: {test_endpoint}")
        
        # Perform health check with timeout
        response = http.request("GET", test_endpoint, timeout=10.0)
        logger.info(f"Response status: {response.status}")
        
        if response.status == 200:
            logger.info("Health check passed")
            return {
                "hookStatus": "SUCCEEDED",
                "reason": "Health check passed with status 200"
            }
        else:
            logger.error(f"Health check failed with status {response.status}")
            return {
                "hookStatus": "FAILED",
                "reason": f"Health check returned status {response.status}"
            }
            
    except urllib3.exceptions.TimeoutError as e:
        logger.error(f"Request timeout: {str(e)}")
        return {
            "hookStatus": "FAILED",
            "reason": f"Request timeout after 10 seconds"
        }
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {
            "hookStatus": "FAILED",
            "reason": f"Exception occurred: {str(e)}"
        }