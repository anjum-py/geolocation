from constructs import Construct
from terraform.imports.google.storage_bucket import (
    StorageBucket,
    StorageBucketVersioning,
    StorageBucketLifecycleRule,
    StorageBucketLifecycleRuleAction,
    StorageBucketLifecycleRuleCondition,
)


class VersionedBucket(Construct):
    """
    A custom construct to create a buckets with lifecycle rules
    """

    def __init__(
        self,
        parent_scope: Construct,
        construct_name: str,
        tf_resource_id: str,
        preferred_region: str,
        bucket_name: str,
        allow_destroy: bool = False,
    ):
        super().__init__(parent_scope, construct_name)

        self.bucket = StorageBucket(
            self,
            tf_resource_id,
            location=preferred_region,
            name=bucket_name,
            versioning=StorageBucketVersioning(enabled=True),
            uniform_bucket_level_access=True,
            force_destroy=allow_destroy,
            lifecycle_rule=[
                StorageBucketLifecycleRule(
                    action=StorageBucketLifecycleRuleAction(type="Delete"),
                    condition=StorageBucketLifecycleRuleCondition(num_newer_versions=10),
                )
            ],
        )
