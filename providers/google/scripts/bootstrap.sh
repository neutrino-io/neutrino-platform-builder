#!/bin/bash
APP_ID=${APP_ID:-foundry360}
APP_NAME=${APP_NAME:-Foundry360}
PLATFORM_ENV=${PLATFORM_ENV:-develop}
PROJECT_FOLDER_ID=${PROJECT_FOLDER_ID:-264578466114}
BILLING_ACCOUNT_ID=${BILLING_ACCOUNT_ID:-018D1E-9B41FF-94600A}
ACCOUNT_EMAIL=${ACCOUNT_EMAIL:-azri@pinc.my}
PROJECT_ID="$APP_ID-$PLATFORM_ENV"

# Create project and add billing
if gcloud projects describe $PROJECT_ID --format='value(projectId)'
then
    echo "$(tput setaf 4)[INFO] $(tput setaf 7)Project $PROJECT_ID exist, switching it to default"
    gcloud config configurations activate $PROJECT_ID
else
    echo "$(tput setaf 4)[INFO] $(tput setaf 7)Creating $PROJECT_ID project.."
    gcloud projects create "$PROJECT_ID" --name "$APP_NAME - $PLATFORM_ENV" --folder=$PROJECT_FOLDER_ID
    gcloud beta billing projects link $PROJECT_ID --billing-account $BILLING_ACCOUNT_ID

    gcloud config configurations create $PROJECT_ID
    gcloud config set account $ACCOUNT_EMAIL
    gcloud config set project $PROJECT_ID
fi

# Enabling core services
echo "$(tput setaf 4)[INFO] $(tput setaf 7)Enabling core services.."
gcloud services enable iam.googleapis.com
gcloud services enable iap.googleapis.com

# Checking for Terraform SA account
if gcloud iam service-accounts describe "terraform-admin@$PROJECT_ID.iam.gserviceaccount.com" --quiet --format='value(name)'
then
    echo "$(tput setaf 4)[INFO] $(tput setaf 7)User terraform-admin@$PROJECT_ID.iam.gserviceaccount.com existed"
else
  # Create SA for Terraform operation
  echo "$(tput setaf 4)[INFO] $(tput setaf 7)Creating Terraform SA"
  gcloud iam service-accounts create terraform-admin --display-name "Terraform Admin"

  # Check for option argument name impersonate
  if [ "$1" = "--impersonate" ]; then
    echo "$(tput setaf 4)[INFO] $(tput setaf 7)Impersonating SA"
    gcloud iam service-accounts add-iam-policy-binding terraform-admin@$PROJECT_ID.iam.gserviceaccount.com --member group:gcp-organization-admins@pinc.my --role roles/iam.serviceAccountTokenCreator
    gcloud iam service-accounts add-iam-policy-binding terraform-admin@$PROJECT_ID.iam.gserviceaccount.com --member group:gcp-organization-admins@pinc.my --role roles/iam.serviceAccountUser

  # If not bind policy as owner ad generate key file
  else
    echo "$(tput setaf 4)[INFO] $(tput setaf 7)Binding SA as owner"
    gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:terraform-admin@$PROJECT_ID.iam.gserviceaccount.com --role roles/owner --quiet

    # Generate SA key file
    gcloud iam service-accounts keys create "./../../credentials/keys/terraform-keyfile-$PLATFORM_ENV.json" --iam-account="terraform-admin@$PROJECT_ID.iam.gserviceaccount.com"
  fi
fi

# Add policies for created SA with impersonation
echo "$(tput setaf 4)[INFO] $(tput setaf 7)Configuring SA IAM policies.."
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:terraform-admin@$PROJECT_ID.iam.gserviceaccount.com --role roles/resourcemanager.projectIamAdmin --quiet
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:terraform-admin@$PROJECT_ID.iam.gserviceaccount.com --role roles/identityplatform.admin --quiet
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:terraform-admin@$PROJECT_ID.iam.gserviceaccount.com --role roles/serviceusage.serviceUsageAdmin --quiet
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:terraform-admin@$PROJECT_ID.iam.gserviceaccount.com --role roles/serviceusage.serviceUsageConsumer --quiet
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:terraform-admin@$PROJECT_ID.iam.gserviceaccount.com --role roles/iam.serviceAccountAdmin --quiet
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:terraform-admin@$PROJECT_ID.iam.gserviceaccount.com --role roles/container.admin --quiet
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:terraform-admin@$PROJECT_ID.iam.gserviceaccount.com --role roles/compute.admin --quiet
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:terraform-admin@$PROJECT_ID.iam.gserviceaccount.com --role roles/storage.admin --quiet
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:terraform-admin@$PROJECT_ID.iam.gserviceaccount.com --role roles/cloudkms.admin --quiet
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:terraform-admin@$PROJECT_ID.iam.gserviceaccount.com --role roles/artifactregistry.admin --quiet
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:terraform-admin@$PROJECT_ID.iam.gserviceaccount.com --role roles/dns.admin --quiet
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:terraform-admin@$PROJECT_ID.iam.gserviceaccount.com --role roles/firebase.admin --quiet
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:terraform-admin@$PROJECT_ID.iam.gserviceaccount.com --role roles/appengine.appAdmin --quiet

# Check if generated keyfile exists
if [ -f "./../../credentials/keys/terraform-keyfile-$PLATFORM_ENV.json" ]
then
  # Exporting GCP auth to env var
  export GOOGLE_APPLICATION_CREDENTIALS="./../../credentials/keys/terraform-keyfile-$PLATFORM_ENV.json"
fi

# OAuth brands
BRAND_ID=`gcloud iap oauth-brands list --quiet --format='value(name)'`
if [ -z "$BRAND_ID" ]
then
    echo "$(tput setaf 4)[INFO] $(tput setaf 7)Configuring OAuth Brand.."
    gcloud iap oauth-brands create --application_title=$APP_NAME --support_email=$ACCOUNT_EMAIL
    BRAND_ID=`gcloud iap oauth-brands list --quiet --format='value(name)'`
else
    echo "$(tput setaf 4)[INFO] $(tput setaf 7)OAuth Brand configured!"
fi
echo "$(tput setaf 4)[INFO] $(tput setaf 7)OAuth Brand ID: $BRAND_ID"

# OAuth clients
IAP_OAUTH_ID=`gcloud iap oauth-clients list $BRAND_ID --quiet --format='value(name)'`
if [ -z $IAP_OAUTH_ID ]
then
    echo "$(tput setaf 4)[INFO] $(tput setaf 7)Configuring OAuth Client.."
    gcloud iap oauth-clients create $BRAND_ID --display_name=$APP_NAME
    IAP_OAUTH_ID=`gcloud iap oauth-clients list $BRAND_ID --quiet --format='value(name)'`
else
    echo "$(tput setaf 4)[INFO] $(tput setaf 7)OAuth Client configured!"
fi

IAP_OAUTH_SECRET=`gcloud iap oauth-clients list $BRAND_ID --quiet --format='value(secret)'`
#CLIENT_ID_REGEX='\bidentityAwareProxyClients\/\s*([^\n\r]*)'
#[[ $IAP_OAUTH_ID =~ $CLIENT_ID_REGEX ]]
#echo ${BASH_REMATCH[1]}
echo "$(tput setaf 4)[INFO] $(tput setaf 7)OAuth Client ID: $IAP_OAUTH_ID"
echo "$(tput setaf 4)[INFO] $(tput setaf 7)OAuth Client Secret: $IAP_OAUTH_SECRET"

# Enabling services
echo "$(tput setaf 4)[INFO] $(tput setaf 7)Enabling extra services.."
gcloud services enable serviceusage.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com