#!/bin/bash

APP_ID=${APP_ID:-neutrino}
PLATFORM_ENV=${PLATFORM_ENV:-develop}
PROJECT_ID="$APP_ID-$PLATFORM_ENV"

gcloud services disable firebasehosting.googleapis.com --force
gcloud services disable firebase.googleapis.com --force
gcloud services disable identitytoolkit.googleapis.com --force
gcloud services disable iap.googleapis.com --force
gcloud services disable cloudresourcemanager.googleapis.com --force
gcloud services disable container.googleapis.com --force
gcloud services disable compute.googleapis.com --force
gcloud services disable servicenetworking.googleapis.com --force
gcloud services disable appengine.googleapis.com --force
gcloud services disable cloudbilling.googleapis.com --force
gcloud services disable clouddeploy.googleapis.com --force
gcloud services disable cloudapis.googleapis.com --force
gcloud services disable serviceusage.googleapis.com --force
gcloud services disable iam.googleapis.com --force

#gcloud iam service-accounts delete terraform-admin@$PROJECT_ID.iam.gserviceaccount.com

# Check if generated keyfile exists
if [ -f "./../../credentials/keys/terraform-keyfile-$PLATFORM_ENV.json" ]
then
  # Exporting GCP auth to env var
  rm -rf ./../../credentials/keys/terraform-keyfile-$PLATFORM_ENV.json
fi