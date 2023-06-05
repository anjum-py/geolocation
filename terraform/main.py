from parse_env import getenv

from terraform import my_constructs
from cdktf import (
    App,
    DataTerraformRemoteStateGcs,
    GcsBackend,
    TerraformOutput,
    TerraformResourceLifecycle,
    TerraformStack,
)
from constructs import Construct

from terraform.imports.google.artifact_registry_repository import ArtifactRegistryRepository
from terraform.imports.google.cloud_run_service import (
    CloudRunService,
    CloudRunServiceTemplate,
    CloudRunServiceTemplateSpec,
    CloudRunServiceTemplateSpecContainers,
    CloudRunServiceTemplateSpecContainersLivenessProbe,
    CloudRunServiceTemplateSpecContainersLivenessProbeHttpGet,
    CloudRunServiceTemplateSpecContainersStartupProbe,
    CloudRunServiceTemplateSpecContainersStartupProbeHttpGet,
    CloudRunServiceTraffic,
)
from terraform.imports.google.cloud_run_service_iam_member import CloudRunServiceIamMember
from terraform.imports.google.cloud_scheduler_job import (
    CloudSchedulerJob,
    CloudSchedulerJobHttpTarget,
    CloudSchedulerJobHttpTargetOauthToken,
)
from terraform.imports.google.cloudbuild_trigger import (
    CloudbuildTrigger,
    CloudbuildTriggerGitFileSource,
    CloudbuildTriggerSourceToBuild,
)
from terraform.imports.google.project_iam_member import ProjectIamMember
from terraform.imports.google.service_account_iam_member import ServiceAccountIamMember


class BaseStack(TerraformStack):
    """
    This stack represents core resources required for setting up cloud infra structure.
    This is kept separate to avoid destroying these resources inadvertently.
    Apply this stack separately and do not include this if you are destroying resources, as it will disable the required APIs and delete the terraform state buckets.
    """

    def __init__(self, parent_scope: Construct, tf_resource_id: str):
        super().__init__(parent_scope, tf_resource_id)

        # Set up terraform google cloud provider
        my_constructs.GoogleCloudProvider(
            self,
            construct_name="base-stack-provider-construct",
            tf_resource_id="google",
            credentials_path=getenv("SVAC_CREDENTIALS_PATH"),
            preferred_region=getenv("REGION_PREFERRED"),
            project_id=getenv("PROJECT_ID"),
        )

        # Set up google storage bucket for remote state
        # This bucket should exist before applying deploying

        GcsBackend(self, bucket=getenv("BUCKET_PRIMARY_TF_STATE"), prefix="base")
        # Create a separate bucket storing terraform state of cloud run service deployment

        # Create a bucket for storing env config
        my_constructs.VersionedBucket(
            self,
            construct_name="env-config-bucket-construct",
            tf_resource_id="env-config-bucket",
            bucket_name=getenv("BUCKET_ENV_CONFIG"),
            preferred_region=getenv("REGION_PREFERRED"),
        )

        # Google Cloud APIs to be enabled
        my_constructs.EnabledAPIs(
            self,
            construct_name="enabled-apis-construct",
        )


class PreCloudRunStack(TerraformStack):
    def __init__(self, parent_scope: Construct, tf_resource_id: str):
        super().__init__(parent_scope, tf_resource_id)

        # Set up terraform google cloud provider
        my_constructs.GoogleCloudProvider(
            self,
            construct_name="privileged-stack-provider-construct",
            tf_resource_id="privileged-stack-provider-google",
            credentials_path=getenv("SVAC_CREDENTIALS_PATH"),
            preferred_region=getenv("REGION_PREFERRED"),
            project_id=getenv("PROJECT_ID"),
        )

        GcsBackend(
            self,
            bucket=getenv("BUCKET_PRIMARY_TF_STATE"),
            prefix="privileged",
        )

        # Create a service account for cloud build
        self.cloud_build_svac = my_constructs.GeolocationCloudBuildSvAc(
            self,
            "geolocation-deploy-svac-construct",
        )

        # Output service email account to access value in cloudrun stack
        TerraformOutput(
            self,
            "cloud-build-svac-email",
            value=self.cloud_build_svac.svac.email,
        )
        TerraformOutput(
            self,
            "cloud-build-svac-name",
            value=self.cloud_build_svac.svac.name,
        )

        # Assign cloud builder role to service account at project level
        ProjectIamMember(
            self,
            "cloudbuild-builder-role",
            role="roles/cloudbuild.builds.builder",
            project=getenv("PROJECT_ID"),
            member=f"serviceAccount:{self.cloud_build_svac.svac.email}",
        )

        # Scheduler job uses OAuth token to authenticate
        # Enable cloud build service account to impersonate itself
        ServiceAccountIamMember(
            self,
            "service-account-user-role",
            role="roles/iam.serviceAccountUser",
            member=f"serviceAccount:{self.cloud_build_svac.svac.email}",
            service_account_id=self.cloud_build_svac.svac.name,
        )

        # Create a container registry
        ArtifactRegistryRepository(
            self,
            "geolocation-artifact-registry",
            format="DOCKER",
            repository_id=getenv("ARTIFACT_REPOSITORY_NAME"),
            location=getenv("REGION_PREFERRED"),
            description="Container image repository for geolocation API",
        )

        # Create a manual cloud build trigger
        cloudbuild_trigger = CloudbuildTrigger(
            self,
            "gelocation-build-trigger",
            name="geolocation-trigger",
            description="Manual cloudbuild trigger to build and push geolocation container image",
            git_file_source=CloudbuildTriggerGitFileSource(
                path="cloudbuild.yaml",
                repo_type="GITHUB",
            ),
            source_to_build=CloudbuildTriggerSourceToBuild(
                ref="refs/heads/dev",
                repo_type="GITHUB",
                uri="https://github.com/anjum-py/geolocation.git",
            ),
            service_account=self.cloud_build_svac.svac.name,
            lifecycle=TerraformResourceLifecycle(
                ignore_changes=[
                    "filename",
                    "git_file_source",
                ]
            ),
        )

        # Schedule weekly trigger for cloud build
        CloudSchedulerJob(
            self,
            "cloud-build-trigger-cron",
            name="geolocation-weekly-build-trigger",
            description="Weekly trigger to rebuild and update geolocation image",
            region=getenv("REGION_PREFERRED"),
            time_zone="Asia/Kolkata",
            schedule="0 0 * * 3",
            paused=False,
            http_target=CloudSchedulerJobHttpTarget(
                uri=f"https://cloudbuild.googleapis.com/v1/projects/{cloudbuild_trigger.project}/locations/global/triggers/{cloudbuild_trigger.trigger_id}:run",
                http_method="POST",
                oauth_token=CloudSchedulerJobHttpTargetOauthToken(
                    service_account_email=self.cloud_build_svac.svac.email,
                ),
            ),
        )

        # Assign scheduler job runner role to service account at project level
        ProjectIamMember(
            self,
            "scheduler-job-runner-binding",
            project=getenv("PROJECT_ID"),
            role="roles/cloudscheduler.jobRunner",
            member=f"serviceAccount:{self.cloud_build_svac.svac.email}",
        )


class DeployCloudRunStack(TerraformStack):
    def __init__(self, parent_scope: Construct, tf_resource_id: str):
        super().__init__(parent_scope, tf_resource_id)

        # Set up terraform google cloud provider
        my_constructs.GoogleCloudProvider(
            self,
            construct_name="cloudrun-stack-provider-construct",
            tf_resource_id="cloudrun-stack-provider-google",
            credentials_path=getenv("SVAC_CREDENTIALS_PATH"),
            preferred_region=getenv("REGION_PREFERRED"),
            project_id=getenv("PROJECT_ID"),
        )

        # Terraform state remote backend on google cloud storage bucket
        GcsBackend(
            self,
            bucket=getenv("BUCKET_PRIMARY_TF_STATE"),
            prefix="cloudrun",
        )

        # Read output of privileged stack from remote bucket
        read_privileged_stack = DataTerraformRemoteStateGcs(
            self,
            "gcs-remote-state",
            bucket=getenv("BUCKET_PRIMARY_TF_STATE"),
            prefix="privileged",
        )

        # Create a dedicated service account for cloud run
        cloud_run_svac = my_constructs.GeolocationCloudRunSvAc(
            self,
            "geolocation-run-svac-construct",
        )

        # Deploy geolocation cloud run service
        cloud_run_svc = CloudRunService(
            self,
            "geolocation-cloudrun-service",
            autogenerate_revision_name=True,
            name=getenv("CLOUDRUN_SERVICE_NAME"),
            location=getenv("REGION_PREFERRED"),
            template=CloudRunServiceTemplate(
                spec=CloudRunServiceTemplateSpec(
                    container_concurrency=200,
                    service_account_name=cloud_run_svac.svac.email,
                    containers=[
                        CloudRunServiceTemplateSpecContainers(
                            image=getenv("CLOUDRUN_IMAGE_LATEST"),
                            # startup_probe=CloudRunServiceTemplateSpecContainersStartupProbe(
                            #     initial_delay_seconds=0,
                            #     timeout_seconds=4,
                            #     period_seconds=5,
                            #     http_get=CloudRunServiceTemplateSpecContainersStartupProbeHttpGet(
                            #         path="/healthz/",
                            #         port=8080,
                            #     ),
                            # ),
                            liveness_probe=CloudRunServiceTemplateSpecContainersLivenessProbe(
                                initial_delay_seconds=5,
                                period_seconds=1800,
                                timeout_seconds=5,
                                http_get=CloudRunServiceTemplateSpecContainersLivenessProbeHttpGet(
                                    path="/healthz/",
                                    port=8080,
                                ),
                            ),
                        ),
                    ],
                ),
            ),
            traffic=[
                CloudRunServiceTraffic(
                    percent=100,
                    latest_revision=True,
                )
            ],
        )

        # Allow unauthenticated requests to pass
        CloudRunServiceIamMember(
            self,
            "cloud-run-allow-all",
            service=cloud_run_svc.name,
            location=getenv("REGION_PREFERRED"),
            role="roles/run.invoker",
            member="allUsers",
        )

        # Custom role to update cloud run service
        cloud_run_update_role = my_constructs.CloudRunUpdateRole(
            self, "cloud-run-update-construct"
        )

        # Enable cloud run service account to write logs
        ProjectIamMember(
            self,
            "cloud-run-write-logs",
            project=getenv("PROJECT_ID"),
            role="roles/logging.logWriter",
            member=f"serviceAccount:{cloud_run_svac.svac.email}",
        )

        # Attach a cloud run service update role to cloud build service account
        CloudRunServiceIamMember(
            self,
            "cloud-run-update-service-role",
            service=cloud_run_svc.name,
            location=getenv("REGION_PREFERRED"),
            role=cloud_run_update_role.role.name,
            member=f"serviceAccount:{read_privileged_stack.get_string('cloud-build-svac-email')}",
        )

        # Allow cloud build account access to act as cloud run account
        ServiceAccountIamMember(
            self,
            "service-account-user-run-role",
            role="roles/iam.serviceAccountUser",
            member=f"serviceAccount:{read_privileged_stack.get_string('cloud-build-svac-email')}",
            service_account_id=cloud_run_svac.svac.name,
        )

app = App()
BaseStack(app, "base")
PreCloudRunStack(app, "pre-cloudrun")
DeployCloudRunStack(app, "cloudrun")
