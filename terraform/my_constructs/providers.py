from constructs import Construct
from terraform.imports.google.provider import GoogleProvider

class GoogleCloudProvider(Construct):
    """
    A custom class representing a Terraform provider for Google Cloud.
    """

    def __init__(
        self,
        parent_scope: Construct,
        construct_name: str,
        tf_resource_id: str,
        credentials_path: str,
        preferred_region: str,
        project_id: str,
    ):
        """
        Initializes an instance of the GoogleCloudProvider class.

        Args:
            parent_scope (Construct): The parent scope of the construct.
            construct_name (str): The name of the construct.
            tf_resource_id (str): The identifier for the Terraform resource.
            credentials_path (str): The path to the file containing the Google Cloud credentials.
            preferred_region (str): Preferred Google Cloud region for the provider.
            project_id (str): Google Cloud project ID to use.
        """
        super().__init__(parent_scope, construct_name)

        # Read the contents of the credentials file
        with open(credentials_path, "r") as file:
            credentials = file.read()

        # Create a GoogleProvider instance with the specified configuration
        self.provider = GoogleProvider(
            self,
            tf_resource_id,
            credentials=credentials,
            region=preferred_region,
            project=project_id,
        )
