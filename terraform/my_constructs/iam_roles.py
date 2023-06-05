from imports.google.project_iam_custom_role import ProjectIamCustomRole
from constructs import Construct

class CloudRunUpdateRole(Construct):
    def __init__(self, parent_scope: Construct, construct_name: str):
        super().__init__(parent_scope, construct_name)

        permissions = [
            "run.services.get",
            "run.services.update",
        ]

        self.role = ProjectIamCustomRole(
            self,
            "cloud-run-update-role",
            permissions=permissions,
            role_id="cloudRunUpdate",
            title="Update Cloud Run Service",
            description="Custom role to only update an existing cloud run service",
        )

