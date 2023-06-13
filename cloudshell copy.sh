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

if ! grep -q "export POETRY_VIRTUALENVS_PREFER_ACTIVE_PYTHON=\"1\"" "$bashrc_file"; then
    echo "export POETRY_VIRTUALENVS_PREFER_ACTIVE_PYTHON=\"1\"" >> "$bashrc_file"
fi
source ~/.bashrc

# Check if pyenv is installed
if command -v pyenv >/dev/null 2>&1; then
    echo "---------------------------------------------------------"
    echo "pyenv is installed. Checking Python version..."
else
    echo "---------------------------------------------------------"
    echo "pyenv is not installed. Installing pyenv..."
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

# Install poetry if not already installed
if ! command -v poetry >/dev/null 2>&1; then
    echo "---------------------------------------------------------"
    echo "Installing poetry..."
    curl -sSL https://install.python-poetry.org | python3 -
fi

# Install cdktf Python package globally using pip
if ! command -v cdktf >/dev/null 2>&1; then
    echo "---------------------------------------------------------"
    echo "Installing cdktf Python package globally..."
    pip install cdktf
fi

# Install cdktf-cli for user using npm
if ! command -v cdktf >/dev/null 2>&1; then
    echo "---------------------------------------------------------"
    echo "Installing cdktf-cli..."
    mkdir -p "${HOME}/.npm-packages"
    npm config set prefix "${HOME}/.npm-packages"
    if ! grep -q "NPM_PACKAGES=\"\${HOME}/.npm-packages\"" "$bashrc_file"; then
        echo "NPM_PACKAGES=\"\${HOME}/.npm-packages\"" >> "$bashrc_file"
    fi

    if ! grep -q "export PATH=\"\$PATH:\$NPM_PACKAGES/bin\"" "$bashrc_file"; then
        echo "export PATH=\"\$PATH:\$NPM_PACKAGES/bin\"" >> "$bashrc_file"
    fi

    if ! grep -q "export MANPATH=\"\${MANPATH-\$(manpath)}:\$NPM_PACKAGES/share/man\"" "$bashrc_file"; then
        echo "export MANPATH=\"\${MANPATH-\$(manpath)}:\$NPM_PACKAGES/share/man\"" >> "$bashrc_file"
    fi
    source ~/.bashrc
    npm install cdktf-cli@latest
fi

if ! gsutil ls -b gs://$BUCKET_PRIMARY_TF_STATE > /dev/null 2>&1; then
    echo "---------------------------------------------------------"
    echo "Creating gs://$BUCKET_PRIMARY_TF_STATE bucket for terraform state"
    gsutil mb -l $REGION_PREFERRED -p $PROJECT_ID -b on gs://$BUCKET_PRIMARY_TF_STATE;
    gsutil versioning set on gs://$BUCKET_PRIMARY_TF_STATE;
    gsutil lifecycle set lifecycle_rule.json gs://$BUCKET_PRIMARY_TF_STATE;
else
    echo "---------------------------------------------------------"
    echo "Terraform state bucket gs://$BUCKET_PRIMARY_TF_STATE exists"
fi

echo "---------------------------------------------------------"
echo "Apply CDKTF base stack"
cdktf deploy base --auto-approve

echo "---------------------------------------------------------"
echo "Copy .env to env-config bucket"
gsutil cp .env gs://$BUCKET_ENV_CONFIG/.env

echo "---------------------------------------------------------"
echo "Apply CDKTF pre-cloudrun stack"
cdktf deploy pre-cloudrun --auto-approve
