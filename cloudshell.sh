#!/bin/bash

python_version_install="3.11.4"
bashrc_file="${HOME}/.bashrc"

# Exporting environment variables
echo "---------------------------------------------------------"
echo "Exporting environment variables"
set -a
. ./.env
echo "Environment variables set"
set +a

# Function to check if a line exists in .bashrc and add it if not
add_line_to_bashrc() {
    if ! grep -q "$1" "$bashrc_file"; then
        echo "$1" >> "$bashrc_file"
    fi
}

# Function to install pyenv and set Python version
install_pyenv_and_python() {
    # Check if pyenv is installed
    if command -v pyenv >/dev/null 2>&1; then
        echo "---------------------------------------------------------"
        echo "pyenv is installed. Checking Python version..."
    else
        echo "---------------------------------------------------------"
        echo "pyenv is not installed. Installing pyenv..."
        curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash

        # Update ~/.bashrc with pyenv configuration if lines don't exist
        add_line_to_bashrc 'export PYENV_ROOT="$HOME/.pyenv"'
        add_line_to_bashrc 'export PATH="$PYENV_ROOT/bin:$PATH"'
        add_line_to_bashrc 'eval "$(pyenv init -)"'

        # Reload the shell
        source ~/.bashrc
        echo "---------------------------------------------------------"
        echo "pyenv installed. Checking Python version..."
    fi

    # Check if Python version is already greater than or equal to 3.11.0
    if python3 -c "import sys; exit(0) if sys.version_info >= (3, 11, 4) else exit(1)"; then
        echo "---------------------------------------------------------"
        echo "Python version is already greater than or equal to 3.11.4"
    else
        echo "---------------------------------------------------------"
        echo "Python version is not installed. Installing Python $python_version_install..."
        pyenv install $python_version_install
        pyenv global $python_version_install
    fi

    # Check if Python version is set to the required version
    if [[ "$(pyenv global)" == "$python_version_install" ]]; then
        echo "Python version $python_version_install is set as the global version."
    else
        pyenv global $python_version_install
        echo "Pyenv global version is set to $(pyenv global)"
    fi
}

# Function to install poetry
install_poetry() {
    # Install poetry
    if ! command -v poetry >/dev/null 2>&1; then
        echo "---------------------------------------------------------"
        echo "Installing poetry..."
        curl -sSL https://install.python-poetry.org | python3 -
    else
        echo "---------------------------------------------------------"
        echo "Poetry is already installed."
    fi
}

# Function to install cdktf globally using pip
install_cdktf() {
    # Install cdktf Python package globally using pip
    if ! command -v cdktf >/dev/null 2>&1; then
        echo "---------------------------------------------------------"
        echo "Installing cdktf Python package globally..."
        pip install cdktf
    else
        echo "---------------------------------------------------------"
        echo "cdktf is already installed."
    fi
}

# Function to install cdktf-cli globally using npm
install_cdktf_cli() {
    # Install cdktf-cli for user using npm
    if ! command -v cdktf >/dev/null 2>&1; then
        echo "---------------------------------------------------------"
        echo "Installing cdktf-cli..."
        npm install -g cdktf-cli@latest
    else
        echo "---------------------------------------------------------"
        echo "cdktf-cli is already installed."
    fi
}

# Function to create or check the existence of the Terraform state bucket
create_or_check_tf_state_bucket() {
    if ! gsutil ls -b gs://$BUCKET_PRIMARY_TF_STATE > /dev/null 2>&1; then
        echo "---------------------------------------------------------"
        echo "Creating gs://$BUCKET_PRIMARY_TF_STATE bucket for Terraform state"
        gsutil mb -l $REGION_PREFERRED -p $PROJECT_ID -b on gs://$BUCKET_PRIMARY_TF_STATE;
        gsutil versioning set on gs://$BUCKET_PRIMARY_TF_STATE;
        gsutil lifecycle set lifecycle_rule.json gs://$BUCKET_PRIMARY_TF_STATE;
    else
        echo "---------------------------------------------------------"
        echo "Terraform state bucket gs://$BUCKET_PRIMARY_TF_STATE exists"
    fi
}

# Function to deploy the CDKTF stacks
cdktf_deploy() {
    echo "---------------------------------------------------------"
    echo "Applying CDKTF base stack"
    cdktf deploy base --auto-approve

    echo "---------------------------------------------------------"
    echo "Copying .env to env-config bucket"
    gsutil cp .env gs://$BUCKET_ENV_CONFIG/.env

    echo "---------------------------------------------------------"
    echo "Applying CDKTF pre-cloudrun stack"
    cdktf deploy pre-cloudrun --auto-approve
}

# Function to destroy the CDKTF stacks
cdktf_destroy() {
    echo "---------------------------------------------------------"
    echo "Destroying CDKTF pre-cloudrun stack"
    cdktf destroy pre-cloudrun --auto-approve

    echo "---------------------------------------------------------"
    echo "Destroying CDKTF base stack"
    cdktf destroy base --auto-approve
}

# Main script logic
if [[ -z "$1" ]]; then
    echo "No arguments provided. Running the entire script..."
    install_pyenv_and_python
    install_poetry
    install_cdktf
    install_cdktf_cli
    create_or_check_tf_state_bucket
    cdktf_deploy
elif [[ "$1" == "prepare" ]]; then
    echo "Preparing environment..."
    install_pyenv_and_python
    install_poetry
    install_cdktf
elif [[ "$1" == "cdktf-cli" ]]; then
    echo "Installing cdktf-cli..."
    install_cdktf_cli
elif [[ "$1" == "cdktf-deploy" ]]; then
    echo "Deploying CDKTF stacks..."
    install_cdktf_cli
    create_or_check_tf_state_bucket
    cdktf_deploy
elif [[ "$1" == "cdktf-destroy" ]]; then
    echo "Destroying CDKTF stacks..."
    install_cdktf_cli
    cdktf_destroy
else
    echo "Invalid argument. Available arguments: prepare, cdktf-cli, cdktf-deploy, cdktf-destroy"
fi
