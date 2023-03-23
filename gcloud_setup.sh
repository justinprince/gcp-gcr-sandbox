PROJECT_ID=sepirak-strapi-dev-381401
SVC_ACCT=tf-svc

gcloud iam service-accounts create tf-svc --description="Terraform testing" --display-name="Terraform service account"

gcloud projects add-iam-policy-binding sepirak-strapi-dev-381401 --member='serviceAccount:tf-svc@sepirak-strapi-dev-381401.iam.gserviceaccount.com' --role='roles/editor'
