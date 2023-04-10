PLATFORM_ENV=${PLATFORM_ENV:-develop}
APP_ORG_ID=${APP_ORG_ID:-neutrino}
APP_ORG_DOMAIN=${APP_ORG_DOMAIN:-neutrino.sh}
APP_ORG_LABEL=${APP_ORG_LABEL:-Neutrino}
PROJECT_ID=${PROJECT_ID:-$APP_ORG_ID-$PLATFORM_ENV}
IAP_SUPPORT_EMAIL=${IAP_SUPPORT_EMAIL:-support@$APP_ORG_DOMAIN}

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null
then
    echo "$(tput setaf 1)[ERROR] $(tput setaf 7)gcloud could not be found, exiting.."
    exit 0
fi

# Check if gcloud is authenticated
GCLOUD_AUTH=$(gcloud auth list --filter-account $ACCOUNT_EMAIL --format='value(account)' --quiet)
if [ "$GCLOUD_AUTH" != "$ACCOUNT_EMAIL" ]
then
    echo "$(tput setaf 1)[ERROR] $(tput setaf 7)gcloud is not authenticated, exiting.."
    exit 0
fi

## Check if gcloud is configured
#if ! gcloud config list --format='value(core.project)' --quiet
#then
#    echo "$(tput setaf 1)[ERROR] $(tput setaf 7)gcloud is not configured, exiting.."
#    exit 0
#fi

# Switch project
PROJECT_EXIST=`gcloud projects describe $PROJECT_ID --format='value(projectId)' --quiet`
if [ "$PROJECT_EXIST" ]
then
    echo "$(tput setaf 4)[INFO] $(tput setaf 7)Project $PROJECT_ID exist, switching it to default"
    
    # Check if configuration exists
    CONFIG_EXIST=`gcloud config configurations describe $PROJECT_ID --format='value(name)' --quiet`
    if [ -z "$CONFIG_EXIST" ]
    then
        # Check if ACCOUNT_EMAIL var provided, if not exit
        if [ -z "$ACCOUNT_EMAIL" ]
        then
            echo "$(tput setaf 1)[ERROR] $(tput setaf 7)ACCOUNT_EMAIL is not provided, exiting.."
            exit 0
        fi

        echo "$(tput setaf 4)[INFO] $(tput setaf 7)Creating configuration for project $PROJECT_ID"
        gcloud config configurations create $PROJECT_ID
        gcloud config set account $ACCOUNT_EMAIL
        gcloud config set project $PROJECT_ID
    fi

    # Check if configuration is active
    CONFIG_ACTIVE=`gcloud config configurations describe $PROJECT_ID --format='value(is_active)' --quiet`
    if [ "$CONFIG_ACTIVE" = "False" ]
    then
        echo "$(tput setaf 4)[INFO] $(tput setaf 7)Activating configuration for project $PROJECT_ID"
        gcloud config configurations activate $PROJECT_ID --quiet
    fi
else
    echo "$(tput setaf 4)[INFO] $(tput setaf 7)Project with ID $PROJECT_ID was not found, exiting.."
    exit 0
fi

# OAuth brands creation
BRAND_ID=`gcloud iap oauth-brands list --format='value(name)' --quiet`
if [ -z "$BRAND_ID" ]
then
    echo "$(tput setaf 4)[INFO] $(tput setaf 7)Configuring OAuth Brand.."
    # Create OAuth brand with quite
    gcloud iap oauth-brands create --application_title=$APP_ORG_LABEL --support_email=$IAP_SUPPORT_EMAIL
    BRAND_ID=`gcloud iap oauth-brands list --format='value(name)' --quiet`

    # Check if brand was created
    if [ -z "$BRAND_ID" ]
    then
        echo "$(tput setaf 1)[ERROR] $(tput setaf 7)OAuth Brand was not created, exiting.."
        exit 0
    fi
else
    echo "$(tput setaf 4)[INFO] $(tput setaf 7)OAuth Brand configured!"
fi

# Display OAuth Brand ID
echo "$(tput setaf 4)[INFO] $(tput setaf 7)OAuth Brand ID: $BRAND_ID"

# OAuth clients
IAP_OAUTH_ID=`gcloud iap oauth-clients list $BRAND_ID --format='value(name)' --quiet`
if [ -z "$IAP_OAUTH_ID" ]
then
    echo "$(tput setaf 4)[INFO] $(tput setaf 7)Configuring OAuth Client.."
    gcloud iap oauth-clients create $BRAND_ID --display_name=$APP_ORG_LABEL --quiet
    IAP_OAUTH_ID=`gcloud iap oauth-clients list $BRAND_ID --format='value(name)' --quiet`

    # Check if client was created
    if [ -z "$IAP_OAUTH_ID" ]
    then
        echo "$(tput setaf 1)[ERROR] $(tput setaf 7)OAuth Client was not created, exiting.."
        exit 0
    fi
else
    echo "$(tput setaf 4)[INFO] $(tput setaf 7)OAuth Client configured!"
fi

# Get OAuth Client Secret
IAP_OAUTH_SECRET=`gcloud iap oauth-clients list $BRAND_ID --format='value(secret)' --quiet`

# Regex to get OAuth Client ID from IAP_OAUTH_ID
# CLIENT_ID_REGEX='\bidentityAwareProxyClients\/\s*([^\n\r]*)'
# [[ $IAP_OAUTH_ID =~ $CLIENT_ID_REGEX ]]
# echo ${BASH_REMATCH}

echo "$(tput setaf 4)[INFO] $(tput setaf 7)OAuth Client ID: $IAP_OAUTH_ID"
echo "$(tput setaf 4)[INFO] $(tput setaf 7)OAuth Client Secret: $IAP_OAUTH_SECRET"