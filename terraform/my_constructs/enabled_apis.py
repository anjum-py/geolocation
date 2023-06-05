import os
from constructs import Construct
from terraform.imports.google.project_service import ProjectService


class EnabledAPIs(Construct):
    def __init__(self, parent_scope: Construct, construct_name: str):
        super().__init__(parent_scope, construct_name)

        enabled_apis = dict(
            cloudresourcemanager="cloudresourcemanager.googleapis.com",
            iam="iam.googleapis.com",
            artifactregistry="artifactregistry.googleapis.com",
            cloudbuild="cloudbuild.googleapis.com",
            cloudscheduler="cloudscheduler.googleapis.com",
            run="run.googleapis.com",
        )
        for api_id, api_name in enabled_apis.items():
            ProjectService(
                self,
                api_id,
                service=api_name,
                project=os.environ["PROJECT_ID"],
                disable_dependent_services=False,
                disable_on_destroy=False,
            )