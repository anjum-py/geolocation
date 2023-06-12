#!/bin/bash

python_version_install="3.11.4"


# Exporting environment variables
echo "#########################################################"
echo "Exporting environment variables"
set -a
. ./.env
POETRY_PREFER_ACTIVE_PYTHON="1"
alias trigger-build='gcloud builds triggers run $CLOUD_BUILD_TRIGGER --branch=main'
set +a

# Check if Python version is already greater than or equal to 3.11.4
if python3 -c "import sys; exit(0) if sys.version_info >= (3, 11, 4) else exit(1)"; then
    echo "#########################################################"
    echo "Python version is already greater than or equal to 3.11.4"
else
    # Check if pyenv is installed
    if command -v pyenv >/dev/null 2>&1; then
        echo "#########################################################"
        echo "pyenv is installed. Installing Python $python_version_install..."
        echo "#########################################################"
        pyenv install $python_version_install
    else
        echo "#########################################################"
        echo "pyenv is not installed. Installing pyenv..."
        echo "#########################################################"
        curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash

        # Update ~/.bashrc with pyenv configuration if lines don't exist
        if ! grep -q "export PYENV_ROOT=\"\$HOME/.pyenv\"" ~/.bashrc; then
            echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
        fi

        if ! grep -q "export PATH=\"\$PYENV_ROOT/bin:\$PATH\"" ~/.bashrc; then
            echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
        fi

        if ! grep -q "eval \"\$(pyenv init -)\"" ~/.bashrc; then
            echo 'eval "$(pyenv init -)"' >> ~/.bashrc
        fi

        # Reload the shell
        source ~/.bashrc

        echo "pyenv installed. Installing Python $python_version_install..."
        pyenv install $python_version_install
    fi
fi
echo "#########################################################"
echo "Set Python $python_version_install to be used globally"
pyenv global $python_version_install

# Install poetry if not already installed
if ! command -v poetry >/dev/null 2>&1; then
    echo "#########################################################"
    echo "Installing poetry..."
    curl -sSL https://install.python-poetry.org | python3 -
fi

# Install cdktf Python package globally using pip
if ! command -v cdktf >/dev/null 2>&1; then
    echo "#########################################################"
    echo "Installing cdktf Python package globally..."
    pip install cdktf
fi

# Install cdktf-cli globally using npm
if ! command -v cdktf >/dev/null 2>&1; then
    echo "#########################################################"
    echo "Installing cdktf-cli..."
    npm install --global cdktf-cli@latest
fi



echo "#########################################################"
echo "Creating bucket for terraform state"
if ! gsutil ls -b gs://$BUCKET_PRIMARY_TF_STATE > /dev/null 2>&1; then
  gsutil mb -l $REGION_PREFERRED -p $PROJECT_ID -b on gs://$BUCKET_PRIMARY_TF_STATE;
  gsutil versioning set on gs://$BUCKET_PRIMARY_TF_STATE;
  gsutil lifecycle set lifecycle_rule.json gs://$BUCKET_PRIMARY_TF_STATE;
fi

echo "#########################################################"
echo "Apply CDKTF base stack"
cdktf deploy base --auto-approve

echo "#########################################################"
echo "Copy .env to env-config bucket"
gsutil cp .env gs://$BUCKET_ENV_CONFIG/.env

echo "#########################################################"
echo "Apply CDKTF pre-cloudrun stack"
cdktf deploy pre-cloudrun --auto-approve

echo "#########################################################"
echo "Trigger cloud build"
trigger-build


