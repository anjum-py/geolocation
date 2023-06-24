from constructs import Construct
from terraform.imports.google.service_account import ServiceAccount


class GeolocationCloudBuildSvAc(Construct):
    def __init__(self, parent_scope: Construct, construct_name: str):
        super().__init__(parent_scope, construct_name)

        self.svac = ServiceAccount(
            self,
            "geolocation-builder-svac",
            account_id="geolocation-builder-svac",
            display_name="Geolocation Builder Service Account",
            description="Dedicated service account for Cloud Build to build and deploy geolocation cloud run service",
        )


class GeolocationCloudRunSvAc(Construct):
    def __init__(self, parent_scope: Construct, construct_name: str):
        super().__init__(parent_scope, construct_name)

        self.svac = ServiceAccount(
            self,
            "geolocation-runner-svac",
            account_id="geolocation-runner-svac",
            display_name="Geolocation Cloud Run Service Account",
            description="Dedicated service account to run geolocation cloud run service with limited permissions",
        )
