# Google Cloud icons

Official Google Cloud icons from [cloud.google.com/icons](https://cloud.google.com/icons), copied unmodified and renamed to `gcloud-<product>.svg` so the diagram scripts can refer to them by name. Google provides them for architecture diagrams and similar use; see that page for its terms.

| File | Source pack | Original file |
|---|---|---|
| `gcloud-cloud-run.svg` | core-products-icons.zip | `CloudRun-512-color-rgb.svg` (also used for Cloud Run functions) |
| `gcloud-cloud-storage.svg` | core-products-icons.zip | `Cloud_Storage-512-color.svg` |
| `gcloud-vertex-ai.svg` | core-products-icons.zip | `VertexAI-512-color.svg` |
| `gcloud-cloud-scheduler.svg` | google-cloud-legacy-icons.zip | `cloud_scheduler.svg` |
| `gcloud-firestore.svg` | google-cloud-legacy-icons.zip | `firestore.svg` |
| `gcloud-cloud-logging.svg` | google-cloud-legacy-icons.zip | `cloud_logging.svg` |
| `gcloud-cloud-audit-logs.svg` | google-cloud-legacy-icons.zip | `cloud_audit_logs.svg` |
| `gcloud-asset-inventory.svg` | google-cloud-legacy-icons.zip | `cloud_asset_inventory.svg` |
| `gcloud-iam.svg` | google-cloud-legacy-icons.zip | `identity_and_access_management.svg` |
| `gcloud-cloud-build.svg` | google-cloud-legacy-icons.zip | `cloud_build.svg` |
| `gcloud-workload-identity-pool.svg` | google-cloud-legacy-icons.zip | `workload_identity_pool.svg` |
| `gcloud-cloud-apis.svg` | google-cloud-legacy-icons.zip | `cloud_apis.svg` |

Google's current full-color icons only cover its core products. For everything else, the product-specific icon is the one in Google's legacy pack, so that's what we use.

To add one: download the pack from cloud.google.com/icons, copy the SVG here as `gcloud-<name>.svg`, add a row above, and use `icon: 'gcloud-<name>'` in a diagram script. `gcloud-*` icons keep their own colors; every other icon name is a line icon from Eraser's catalog, tinted to match the text.
