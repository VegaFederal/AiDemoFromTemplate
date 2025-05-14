import json
import boto3
import logging
import os
import re

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    try:
        logger.info("Event received")
        
        # Handle direct Lambda console invocation
        if isinstance(event, dict) and 'prompt' in event:
            prompt = event['prompt']
            logger.info("Direct invocation with prompt")
        # Handle OPTIONS requests for CORS
        elif isinstance(event, dict) and event.get('httpMethod') == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'OPTIONS,POST',
                    'Content-Type': 'application/json'
                },
                'body': '{}'
            }
        # Handle CloudFormation custom resource request
        elif isinstance(event, dict) and 'RequestType' in event:
            logger.info("Handling CloudFormation custom resource request")
            return {
                'Status': 'SUCCESS',
                'PhysicalResourceId': event.get('PhysicalResourceId', 'default-id'),
                'StackId': event.get('StackId', ''),
                'RequestId': event.get('RequestId', ''),
                'LogicalResourceId': event.get('LogicalResourceId', '')
            }
        # Handle API Gateway requests
        elif isinstance(event, dict) and 'body' in event:
            if not event['body']:
                return {
                    'statusCode': 400,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({'error': 'Missing or empty request body'})
                }
            
            # Handle both string and JSON body
            body = event['body']
            if isinstance(body, str):
                try:
                    body = json.loads(body)
                except json.JSONDecodeError:
                    return {
                        'statusCode': 400,
                        'headers': {'Content-Type': 'application/json'},
                        'body': json.dumps({'error': 'Invalid JSON in request body'})
                    }
            
            prompt = body.get('prompt')
        else:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Invalid request format'})
            }
        
        if not prompt:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Missing prompt in request'})
            }
        
        # Get model ID from environment variable or use default
        model_id = os.environ.get('MODEL_ID', 'amazon.nova-pro-v1:0')
        logger.info(f"Using model: {model_id}")
        
        # Initialize Bedrock client using the current region
        region = os.environ.get('AWS_REGION')
        bedrock = boto3.client('bedrock-runtime', region_name=region)
        
        # Configure the request based on model type
        if re.match(r'arn:', model_id):
            # Claude models use anthropic message format
            request_body = {
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 1000,
                "messages": [
                    {"role": "user", "content": [{"type": "text", "text": prompt}]}
                ]
            }
        else:
            # Default to Nova format
            messages = [{"role": "user", "content": [{"text": prompt}]}]
            request_body = {
                "schemaVersion": "messages-v1",
                "messages": messages
            }
        
        # Call Bedrock with the prompt
        logger.info(f"Sending request to Bedrock, model = {model_id}")
        response = bedrock.invoke_model(
            modelId=model_id,
            body=json.dumps(request_body)
        )
        
        # Parse the response
        response_body = json.loads(response['body'].read())
        logger.info("Response received from Bedrock")
        
        # Extract the generated text based on model type
        if re.match(r'arn:', model_id):
            # Claude response format
            content_items = response_body.get('content', [])
            generated_text = ""
            for item in content_items:
                if item.get('type') == 'text':
                    generated_text += item.get('text', '')
            if not generated_text:
                generated_text = "No response text"
        else:
            # Nova response format
            generated_text = response_body.get('output', {}).get('message', {}).get('content', [{}])[0].get('text', 'No response text')
        
        # For direct Lambda console invocation, return just the text
        if isinstance(event, dict) and 'prompt' in event and 'body' not in event and 'httpMethod' not in event:
            return {'response': generated_text}
        
        # For API Gateway, return formatted response
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({'response': generated_text})
        }
    except Exception as e:
        logger.error(f"Error: {str(e)}", exc_info=True)
        # For direct Lambda console invocation
        if isinstance(event, dict) and 'prompt' in event and 'body' not in event and 'httpMethod' not in event:
            return {'error': str(e)}
        # For API Gateway
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        }