## Introduction

This GitHub repository hosts the source code for an API built using FastAPI Python web framework.  The main functionality of this API is to provide geolocation information based on an IP address. We use MaxMind GeoLite2 databases to lookup public IP addresses. The main focus of this project was to learn and understand the intricacies involved in automated deployment of a microservice to Google Cloud's managed, serverless containers platform, Cloud Run. I used Cloud Development Kit for Terraform (CDKTF) to automate deployment of the required infrastructure components to secure and run our microservice.

For more information on the design and tech stack used, please refer to [Building Geolocation API](https://anjum-py.github.io/projects/building-geolocation-api/) on my portfolio page for this project.

## Project Overview

The geolocation-api project comprises five distinct components:

1. FastAPI Application: The FastAPI application is responsible for handling web requests and retrieving geolocation data from MaxMind GeoLite2 databases. Along with the FastAPI python web framework, it has a few dependencies including `geoip2`. The application includes middleware components for `TrustedHost` and `CORS` handling. It also defines endpoints for health checks and IP geolocation lookup.
2. `Dockerfile`:  The `Dockerfile` employs a multi-stage build approach. In the first stage, it creates a configuration file required by `geoipupdate` program and downloads GeoLite2 MaxMind databases. In the second stage, it uses the Python slim-buster image, installs dependencies, and sets up the python virtual environment. In the third and final stage, it simply brings everything together.
3. `Cloudbuild.yaml`:  This file defines the steps for build pipeline for Google Cloud's Cloud Build service. It consists of steps for copying the `.env` file, running tests, building and pushing the Docker image, and updating the Cloud Run service with a new revision.
4. CDKTF Application: CDKTF is used to define and provision the cloud infrastructure required for our API. Our CDKTF application has three stacks. The `base` stack that enables required Google Cloud APIs and creates a bucket to store our `.env` file. The `pre-cloudrun` stack creates a dedicated service account for Cloud Build pipeline, creates Artifact Registry to store Docker container images, sets up Cloud Build trigger for manual invocation, and creates a Cloud Scheduler job to automatically trigger a weekly build of our image. The `cloudrun` stack creates a dedicated service account to be used with our Cloud Run service, then creates Cloud Run service using the image we built using Cloud Build, and configures the service to be available for everyone.
5. `deploy.sh` Shell Script: The `deploy.sh` script automates the set up of the Cloud Shell environment by installing required components such as required version of Python, Poetry for managing virtual environment, CDKTF python bindings, and cdktf-cli npm package and then runs our `cdktf deploy` commands to deploy cloud resources.

I hope this overview has given you a good understanding of the project's structure and components. In this [YouTube video](https://youtu.be/M1O_V5VSibg), I provide more detailed walkthrough of each piece, explaining the code and highlighting essential concepts. Please watch the video to learn more about this project.

## Accompanying Youtube Video

If you'd rather watch a video instead of reading a long article, here is a link to [YouTube video](https://youtu.be/MTqIj9ycPLY) that accompanies this article.

## Live Demo

Explore a live demo of the Geolocation API hosted on my Google Cloud platform, running as a Cloud Run revision, [on this page](https://anjum-py.github.io/projects/deploying-geolocation-api-deployment-guide/#demo). Enter a valid public IP address, whether IPv4 or IPv6, to retrieve its details. If no input is provided, the API will return details of your own IP address.

You will find the OpenAPI docs [here](https://geolocation-api-zuravksy3a-el.a.run.app/docs/).

## Overview of deployment steps

- We will start with getting a MaxMind developer account to obtain a license key. This key will be used in our `Dockerfile` to download latest GeoLite2 databases.
- We will login into our Google Cloud Platform to create a project and use Google Cloud Shell to deploy required components.
- We will fork the GitHub repository to be able to connect to Cloud Build trigger.
- We will connect our GitHub repository to Cloud Build trigger to use it as a source.
- We will use `.env` file to customise and configure our environment.
- We will use `deploy.sh` shell script to prepare Google Cloud Shell Console VM and deploy our FastAPI application.

Let's begin by going through each item on this list, one at a time.

## Create a MaxMind Developer Account

To set up automatic database updates within our container, we need to create a MaxMind account and obtain a license key. To do this:

1. Go to the MaxMind website and [sign up](https://www.maxmind.com/en/geolite2/signup) for an account to access GeoLite2 databases.
2. Check your email for a verification link. Click on the link to set a password for your account.
3. Log in to your MaxMind account. You will receive a verification code via email. Copy and paste the verification code to complete the authentication process.
4. On your account dashboard, click on "**Manage License Keys**" in the left sidebar.
5. Click on "**Create New License Key**" and enter a name for your license key.
6. Click on "**Create**" to generate your license key.

Keep your license key window open as we will need it shortly.

## Create **a Google Cloud Project**

Before we begin, please make sure that you are logged in to your Google Cloud account and have a valid billing account. You may be charged for using Google Cloud services, but Google Cloud’s free tier is more than enough to test our deployment without incurring any cost.

The free tier includes a set of Google Cloud services that you can use for free, up to certain usage limits. If you exceed the usage limits, you will be charged for the additional usage.

The free tier is a great way to try out Google Cloud services and to test our deployment without incurring any cost.

If you do not want to continue using the service, our CDKTF implementation makes it very easy to delete the deployed resource in just one command.

1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Click on the **Sign in** button.
3. Enter your Google Account email address and password.
4. Click on the **Sign in** button.

Once you are logged in, you will be taken to the Google Cloud Platform console. From here, you can start using Google Cloud services.

To create a new Google Cloud project for deploying our geolocation service, follow these steps:

1. Click on the **Select Project** button located in the top-left corner of the GCP Console.
2. Click on "**New Project**" to create a new project.
3. In the "**Project Name**" field, enter "**geolocation**."
4. Make a note of the random project ID that Google Cloud assigns. This is required to be unique globally, so Google Cloud assigns a random number to the name.
5. Click "**Create**."
6. Click on the **Select Project** button and select the newly created project to make it the active project.

You can also select the project by clicking on Select Project dropdown button located in top-left corner of the GCP console and then selecting the project.

To learn more about creating a project on Google Cloud Platform, follow this [guide](https://cloud.google.com/resource-manager/docs/creating-managing-projects#creating_a_project).

## Fork and Clone the Git Repository

We need to fork the [Git repository](https://github.com/anjum-py/geolocation) because Cloud Build only allows connecting to repositories from our own GitHub account, even if the repository is public. Forking a repository creates a copy of it in our own account, which we can then clone to our Cloud Shell environment. Once the repository is cloned, we can connect it to our Cloud Build trigger.

Here is a more detailed explanation of the steps involved:

1. Go to the [GitHub repository](https://github.com/anjum-py/geolocation).
2. Click the **Fork** button in the top right corner of the page.
3. This will create a copy of the repository in our own GitHub account.
4. Once the repository has been forked, click the **Clone** button.
5. In the **Clone with HTTPs** section, copy the URL of the repository.
6. Open a terminal window in our Cloud Shell environment.
7. Type the following command to clone the repository: `git clone <URL>`

Replace `<URL>` with the URL that we copied in step 5.

The repository will be cloned to our Cloud Shell environment.

## Connect git repository

In this step, we authenticate and connect GitHub repository to cloudbuild trigger.

To connect our GitHub repository to Cloud Build, follow these steps:

1. Go to the **[Repositories](https://console.cloud.google.com/cloud-build/repositories/)** page in the **Google Cloud Console**.
2. Scroll to the bottom of the page and click **Connect Repository**.
3. Leave the **Region** as **global** and make sure **GitHub** is selected.
4. Click **Continue**.
5. If you are not already logged in to GitHub, you will be prompted to do so.
6. Once you are logged in, click **Authorize Google Cloud Build by GoogleCloudBuild**.
7. Click **Connect** to connect your repository.

Do not create a trigger yet. We will do it using cdktf.

## Create `.env` file

Our CDKTF stacks depend on values from `.env` file for setting up our infrastructure

To set up `.env` file, follow these steps:

1. Click the **Activate Cloud Shell** button at the top of the page.
2. Wait for the Cloud Shell session to open.
3. Click "**Open Editor**" to open file editor.
4. Copy the contents of the `example_env.txt` file.
5. Create a new file and paste the copied content.
6. Save the file as `.env` in the root directory of your cloned repository.
7. Find the random numeric ID assigned to your project ID by Google and set it to `RANDOM_ID` variable.
8. Set your preferred Google Cloud region to variable `REGION_PREFERRED`.
9. Set the URL of your forked git repository to variable `GIT_SOURCE_REPOSITORY`.
10. If you will be using this API from a front end, set the `FASTAPI_CORS_ORIGINS` variable accordingly.
11. Find the account ID and license key of your MaxMind account and assign these values to `GEOIPUPDATE_ACCOUNT_ID` and `GEOIPUPDATE_LICENSE_KEY` environment variables respectively.

Be sure to remove any unwanted spaces after the equal sign or after the variable value.

Our `.env` file is now configured and we are ready to deploy our Cloud Run service.

## Run `deploy.sh` script

In this final step, we execute our `deploy.sh` script. In order to learn what our script does in detail, please refer to Building Geolocation API video. From a deployment standpoint, in a fresh and clean cloud shell environment, our script will first prepare our Cloud Shell VM and then deploy our CDKTF stacks one by one.

When I initially started working on the project, I began documenting the steps to write a detailed guide for setting up the Cloud Shell VM to deploy our microservice.  However, I realized that most of this work can be easily automated and a simple shell script would be more beneficial and user-friendly for everyone involved.

Consequently, I went ahead and created a shell script that handles the setup and deployment of our foundational CDKTF stacks. We then had to trigger the build manually once before we could deploy our third and final CDKTF stack to deploy our Cloud Run service.

In this version of the script, I was using `pyenv` to set up python version globally and there were a couple of manual steps to be taken in the exact order at a particular point in time. This was making it a little difficult to understand and troubleshoot. So, I spent some more time to refactor and make the script better and the result was fully automated end to end deployment of our microservice Geolocation API with just one command.

To execute our script, make sure you are in the project root directory and run `./deploy.sh` script.

```
# make sure we are in the right directory
cd ~/geolocation
./deploy.sh
```

If prompted, select `Authorize` to continue.

Now, sit back and watch our Cloud Shell VM get set up and our Cloud Run service get built, tested, and deployed on Cloud Run.

This script actually does a lot of work and to understand more, please watch my video about Building Geolocation API where I walk through the code and delve into how various tools work together and how this shell script brings everything together. It should take approximately 12 minutes for setting up VM, building the container image, and then deploying a cloud run revision.

## The Finish Line: Completing the Deployment Journey

At this stage, we should have a running Cloud Run revision for our geolocation service. You can check the status of our deployed Cloud Run service [here](https://console.cloud.google.com/run). Click on the service link to open the Cloud Run page and access the url the service is hosted on.

Also, check for configured weekly schedule to trigger our Cloud Build [here](https://console.cloud.google.com/cloudscheduler). So, every week, our Cloud Build will get triggered and rebuild the image with updated MaxMind GeoLite2 databases and deploy the new Cloud Run revision.

It took quite a bit of work to reach here, but from now on, automation will take over. Now, we can use this API in any number of applications that needs geolocation information. We do not have to worry about keeping the databases up to date or the scalability of the service. Cloud Run by design will spin up as many containers as required based on the demand and when there is no demand, Cloud Run will terminate all containers and scale the service down to zero.  We are billed only for the time our containers are serving requests.

Thank you for reading. I hope you find this useful. I know there is a lot that can be improved.  Your feedback and suggestions are very important to me. Please take a moment to leave a comment.