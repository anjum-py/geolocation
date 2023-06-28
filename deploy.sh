#!/bin/bash

PYTHON_VERSION_INSTALL="3.11.4"
BASHRC_FILE="${HOME}/.bashrc"
NPM_ROOT="${HOME}/npm-packages"
NPM_BIN_PATH="${NPM_ROOT}/node_modules/.bin"
POETRY_HOME="${HOME}/poetry"
POETRY_PATH=${POETRY_HOME}/venv/bin/poetry
PYENV_ROOT="${HOME}/.pyenv"

cloudrun_service_exists(){
    gcloud run services describe ${CLOUDRUN_SERVICE_NAME} \
        --region ${REGION_PREFERRED} \
        --project=${PROJECT_ID} \
        --format="value(status.url)";
}
container_image_exists(){
    gcloud artifacts docker images describe \
    ${CLOUDRUN_IMAGE_LATEST} \
    --project=${PROJECT_ID};
}
cloudbuild_trigger_exists(){
   gcloud beta builds triggers describe \
   ${CLOUD_BUILD_TRIGGER} \
   --project=${PROJECT_ID};
}
trigger_and_get_build_id(){
    gcloud beta builds triggers run \
    ${CLOUD_BUILD_TRIGGER} \
    --branch=main \
    --format="value(metadata.build.id)" \
    --project=${PROJECT_ID};
}
deploy_cloudrun_revision(){
    gcloud run deploy ${CLOUDRUN_SERVICE_NAME} \
    --image ${CLOUDRUN_IMAGE_LATEST} \
    --region ${REGION_PREFERRED} \
    --project=${PROJECT_ID};
}

# Exporting environment variables
set -a
. ./.env
set +a

# Function to check if a line exists in .bashrc and add it if not
add_line_to_bashrc() {
    if ! grep -q "$1" "$BASHRC_FILE"; then
        echo "$1" >> "$BASHRC_FILE"
    fi
}

# Function to update the lookup PATH if the provided path does not exist

update_path_if_not_exists(){
    local path_to_add="$1"
    if [[ ":$PATH:" != *":$path_to_add:"* ]]; then
        export PATH="$path_to_add:$PATH"
    fi
}

# Make sure NPM_BIN_PATH is in PATH
update_path_if_not_exists ${NPM_BIN_PATH}

# Function to install cdktf-cli in user's home directory
install_cdktf_cli() {
    if ! command -v cdktf >/dev/null 2>&1; then
        echo "---------------------------------------------------------"
        echo "- Installing cdktf-cli..."
        mkdir -p "$NPM_ROOT"
        cd $NPM_ROOT
        npm init --yes
        npm install cdktf-cli@latest
    else
        echo "---------------------------------------------------------"
        echo "- cdktf-cli is already installed."
    fi
}

# Make sure POETRY_PATH is in PATH
update_path_if_not_exists ${POETRY_PATH}

# Install python poetry
install_poetry() {
    # Install poetry
    if ! command -v poetry >/dev/null 2>&1; then
        echo "---------------------------------------------------------"
        echo "- Installing poetry..."
        echo $(pwd)
        mkdir -p "$POETRY_HOME"
        curl -sSL https://install.python-poetry.org | python3 -
        poetry --version
    else
        echo "---------------------------------------------------------"
        echo "- Poetry is already installed."
    fi
}

# Make sure PYENV_ROOT is in PATH
update_path_if_not_exists ${PYENV_ROOT}/bin

# Function to install Pyenv
install_pyenv() {
    if command -v pyenv >/dev/null 2>&1; then
        echo "---------------------------------------------------------"
        echo "- Pyenv is already installed."
    else
        echo "---------------------------------------------------------"
        echo "- Pyenv is not installed. Installing pyenv..."
        curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash
        add_line_to_bashrc 'export PYENV_ROOT="$HOME/.pyenv"'
        add_line_to_bashrc 'export PATH="$PYENV_ROOT/bin:$PATH"'
        add_line_to_bashrc 'eval "$(pyenv init -)"'
        source "$BASHRC_FILE"
    fi
}


# Function to install Python using Pyenv
install_python_with_pyenv() {
    if pyenv versions --bare | grep -qF "${PYTHON_VERSION_INSTALL}"; then
        echo "- Python ${PYTHON_VERSION_INSTALL} is already installed with Pyenv."
    else
        echo "- Installing Python ${PYTHON_VERSION_INSTALL} with Pyenv..."
        pyenv install "${PYTHON_VERSION_INSTALL}"
        echo "- Python ${PYTHON_VERSION_INSTALL} is installed with Pyenv."
    fi
}

# Function to create poetry virtualenv
create_poetry_virtualenv() {
    pyenv local ${PYTHON_VERSION_INSTALL}
    poetry env use "$PYTHON_VERSION_INSTALL"
    poetry install --only cdktf
}

# Function to create or check the existence of the Terraform state bucket
create_or_check_tf_state_bucket() {
    if ! gsutil ls -b gs://$BUCKET_PRIMARY_TF_STATE > /dev/null 2>&1; then
        echo "---------------------------------------------------------"
        echo "- Creating gs://$BUCKET_PRIMARY_TF_STATE bucket for Terraform state"
        gsutil mb -l $REGION_PREFERRED -p $PROJECT_ID -b on gs://$BUCKET_PRIMARY_TF_STATE;
        gsutil versioning set on gs://$BUCKET_PRIMARY_TF_STATE;
        gsutil lifecycle set lifecycle_rule.json gs://$BUCKET_PRIMARY_TF_STATE;
    else
        echo "---------------------------------------------------------"
        echo "- Terraform state bucket gs://$BUCKET_PRIMARY_TF_STATE exists"
    fi
}

# Function to check if the terraform providers have been imported
cdktf_get() {
    update_path_if_not_exists $(poetry env info -p)/bin
    if [[ ! -d "terraform/imports" ]]; then
        echo "---------------------------------------------------------"
        echo "- The terraform/imports directory does not exist."
        echo "- Running 'cdktf get' command..."
        cdktf get
    else
        echo "---------------------------------------------------------"
        echo "- The terraform/imports directory already exists."
    fi
}

# Function to run cdktf synth command
cdktf_synth() {
    update_path_if_not_exists $(poetry env info -p)/bin
    create_or_check_tf_state_bucket
    echo "---------------------------------------------------------"
    echo "- Running 'cdktf synth' command..."
    cdktf synth
}

# Function to run foundational cdktf stacks and copy .env file
cdktf_deploy_base() {

    update_path_if_not_exists $(poetry env info -p)/bin
    create_or_check_tf_state_bucket

    echo "---------------------------------------------------------"
    echo "- Deploying base cdktf stack"
    cdktf deploy base --auto-approve

    echo "---------------------------------------------------------"
    echo "- Deploying pre-cloudrun cdktf stack"
    cdktf deploy pre-cloudrun --auto-approve

    echo "---------------------------------------------------------"
    echo "- Copying .env to env-config bucket"
    gsutil cp .env gs://$BUCKET_ENV_CONFIG/.env
}

# Function to deploy cloudrun stack
cdktf_deploy_cloudrun() {
    update_path_if_not_exists $(poetry env info -p)/bin
    container_image_exists &>/dev/null;
    if [ $? == 0 ]; then
        echo "---------------------------------------------------------"
        echo "- Deploying cloudrun stack"
        cdktf deploy cloudrun --auto-approve
    fi
}

# Function to monitor trigger build and wait for its completion
check_build_status() {
    local build_id=$1
    local start_time=$(date +%s)
    echo "---------------------------------------------------------"
    echo - logsUrl - $(gcloud builds describe "${build_id}" --format="value(logUrl)")

    while true; do
        build_status=$(gcloud builds describe "${build_id}" --format="value(status)")
        elapsed_time=$(( $(date +%s) - start_time ))
        formatted_time=$(date -u -d @${elapsed_time} +"%H:%M:%S")

        case $build_status in
            STATUS_UNKNOWN | WORKING | PENDING | QUEUED)
                echo "---------------------------------------------------------"
                echo "- Build status - $build_status"
                echo "- Elapsed Time: ${formatted_time}"
                sleep 30
                ;;
            SUCCESS)
                echo "---------------------------------------------------------"
                echo "- Build status - $build_status"
                echo "- Elapsed Time: ${formatted_time}"
                return 0
                ;;
            FAILURE | TIMEOUT | INTERNAL_ERROR | CANCELLED | EXPIRED)
                echo "---------------------------------------------------------"
                echo "- Build status - $build_status"
                echo "- Elapsed Time: ${formatted_time}"
                return 1
                ;;
            *)
                echo "---------------------------------------------------------"
                echo "- Unknown build status: ${build_status}. Total Time: ${formatted_time}"
                return 1
                ;;
        esac
    done
}

# Function to trigger cloud build
trigger_build(){
    cloudbuild_trigger_exists > /dev/null 2>&1
    if [ $? == 0 ]; then
        echo "---------------------------------------------------------"
        echo "- Triggering the build and watching for it to complete";
        local build_id
        build_id=$(trigger_and_get_build_id)
        check_build_status $build_id
    else
        echo "- Required image could not be located."
    fi
}

# Function to update cloudrun revision if image exists, else trigger cloudbuild
update_cloudrun_revision(){
    container_image_exists &>/dev/null;
    if [ $? == 0 ]; then
        echo "---------------------------------------------------------"
        echo "- Image - ${CLOUDRUN_IMAGE_LATEST} - exists";

        cdktf_deploy_cloudrun

        echo "---------------------------------------------------------"
        echo "- Attempting to deploy Cloud Run revision";
        deploy_cloudrun_revision

    else

        echo "---------------------------------------------------------"
        echo "- Container image does not exist"
        echo "- Attempting to trigger a build"
        trigger_build

        cdktf_deploy_cloudrun

        echo "---------------------------------------------------------"
        echo "- Attempting to deploy Cloud Run revision";
        deploy_cloudrun_revision
    fi
}

# Function to destroy cdktf stacks
cdktf_destroy(){
    echo "---------------------------------------------------------"
    echo "- Destroy cloudrun stack";
    cdktf destroy cloudrun --auto-approve;

    echo "---------------------------------------------------------"
    echo "- Destroy pre-cloudrun stack";
    cdktf destroy pre-cloudrun --auto-approve;

    echo "---------------------------------------------------------"
    echo "- Destroy base stack";
    cdktf destroy base --auto-approve;
}

# Main script logic
if [[ -z "$1" ]]; then
    ./deploy.sh prepare
    ./deploy.sh deploy
elif [[ "$1" == "cdktf-cli" ]]; then
    install_cdktf_cli
elif [[ "$1" == "poetry" ]]; then
    install_poetry
elif [[ "$1" == "pyenv" ]]; then
    install_pyenv
elif [[ "$1" == "python" ]]; then
    install_pyenv
    install_python_with_pyenv
elif [[ "$1" == "poetry-env" ]]; then
    create_poetry_virtualenv
elif [[ "$1" == "cdktf-get" ]]; then
    cdktf_get
elif [[ "$1" == "cdktf-synth" ]]; then
    cdktf_synth
elif [[ "$1" == "cdktf-deploy-base" ]]; then
    cdktf_deploy_base
elif [[ "$1" == "cdktf-deploy-cloudrun" ]]; then
    cdktf_deploy_cloudrun
elif [[ "$1" == "update-revision" ]]; then
    update_cloudrun_revision
elif [[ "$1" == "update-revision-build" ]]; then
    deploy_cloudrun_revision
elif [[ "$1" == "force-rebuild" ]]; then
    trigger_build
    update_cloudrun_revision
elif [[ "$1" == "prepare" ]]; then
    install_cdktf_cli
    install_poetry
    install_pyenv
    install_python_with_pyenv
    create_poetry_virtualenv
    cdktf_get
elif [[ "$1" == "deploy" ]]; then
    cdktf_deploy_base
    update_cloudrun_revision
elif [[ "$1" == "destroy" ]]; then
    cdktf_destroy
else
    echo "Invalid argument."
    echo "Available arguments"
    echo "- cdktf-cli : Install CDKTF CLI npm package"
    echo "- poetry : Install poetry - Python package manager"
    echo "- pyenv : Install pyenv to use specific python version"
    echo "- python : Install python ${PYTHON_VERSION_INSTALL} using pyenv"
    echo "- poetry-env : Create and set up poetry virtual environment"
    echo "- cdktf-get : Run 'cdktf get' command"
    echo "- cdktf-synth : Run 'cdktf synth' command"
    echo "- cdktf-deploy-base : Deploy CDKTF stacks base and pre-cloudrun and copy .env file"
    echo "- force-rebuild : Forces a Cloud Build trigger"
    echo "- prepare : Installs cdktf-cli, poetry, pyenv, python, create poetry-env, runs 'cdktf get' command"
    echo "- update-revision : Deploys a new Cloud Run revision"
    echo "- update-revision-build : Simple Cloud Run revision deployment, meant to be used in cloudbuild.yaml"
    echo "- deploy : Combines cdktf-deploy-base + update-revision"
    echo "- destroy : Destroy all stacks"
fi
