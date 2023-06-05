## About this project

In this portfolio project, I built an API that looks up IP addresses from MaxMind GeoLite2 databases. This API is powered by FastAPI and MaxMind GeoLite2 databases and provides one endpoint. If the request includes a POST body with `ip_address`, the endpoint will look up the requested IP address or the endpoint will lookup the origin IP address of the request as long as this public IP address is in MaxMind databases.

The main focus of this project was to learn and understand the intricacies involved in automated deployment of a microservice to Google Cloud's managed, serverless containers platform, Cloud Run. I used Cloud Development Kit for Terraform (CDKTF) to automate deployment of the required infrastructure components to secure and run our microservice.

Deployment instructions and demo is available [here]()