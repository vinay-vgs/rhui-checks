#!/bin/bash

##################################################################################
#                                                                                #
# Copyright 2020 Google Inc. All rights reserved.                                #
#                                                                                #
# Licensed under the Apache License, Version 2.0 (the "License");                #
# you may not use this file except in compliance with the License.               #
# You may obtain a copy of the License at                                        #
#                                                                                #
#     http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                                #
# Unless required by applicable law or agreed to in writing, software            #
# distributed under the License is distributed on an "AS IS" BASIS,              #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.       #
# See the License for the specific language governing permissions and            #
# limitations under the License.                                                 #
#                                                                                #
# Author: Vinay Gahlout                                                          #
#                                                                                #
# Name: RHUI basic checks tool                                                   #
#                                                                                #
# Description: This script will help with Basic checks related to RHUI setup.    #
#                                                                                #
##################################################################################

Metadata_URL="http://169.254.169.254"

platform_get() {
    echo -e "\n######################## Platform check ########################"
    if [ -n "$1" ]; then
        platform=`echo $1`
    else
        if /usr/sbin/dmidecode | grep -qi "Google"; then 
            platform="GCP"
        elif /usr/sbin/dmidecode | grep -qi "Amazon"; then
            platform="AWS"
        elif /usr/sbin/dmidecode | grep -qi "Microsoft"; then
            platform="Azure"
        else
            platform="Unknown"
        fi
    fi
    echo "Instance is identified to be running on $platform platform"
}
platform_get

check_os_version() {
    echo -e "\n######################## Checking OS release & version ########################"
    if cat /etc/redhat-release| grep -q "Red Hat" ; then
        os_version=$(awk -F'=' '$1 == "VERSION_ID" {print $2}' /etc/os-release)
        os_major_version=$(echo "${os_version%%.*}" | tr -d '"')
        echo "OS is identified as Red Hat Enterprise Linux $os_version"
    else
        another_os=$(awk -F'=' '$1 == "NAME" {print $2}' /etc/os-release)
        echo "This script is designed only for Red Hat Enterprise Linux.\
             Current OS is $another_os, Exiting now!!"
        exit 1
    fi

}
check_os_version

licnese_check(){

    case $1 in 
        "2862452038400965874" )
            license=rhel-6-byol
            ;;
        "4720191914037931587" )
            license=rhel-6-byos
            ;;

        "1176308840663243801" )
            license=rhel-6-els
            ;;
        "1000002" )
            license=rhel-6-server
            ;;

        "4621277670514851623" )
            license=rhel-7-byol
            ;;
        "1492188837615955530" )
            license=rhel-7-byos
            ;;

        "4646774207868449156" )
            license=rhel-7-els
            ;;
        "1000006" )
            license=rhel-7-server
            ;;

        "8475125252192923229" )
            license=rhel-8-byos
            ;;

        "601259152637613565" )
            license=rhel-8-server
            ;;
        "3837518230911135854" )
            license=rhel-9-byos
            ;;

        "7883559014960410759" )
            license=rhel-9-server
            ;;

        "8555687517154622919" )
            license=rhel-7-sap
            ;;

        "5955710252559838163" )
            license=rhel-7-sap-apps
            ;;

        "996690525257673675" )
            license=rhel-7-sap-hana
            ;;

        "1785892118823772022" )
            license=rhel-7-sap-solutions
            ;;

        "5882583258875011738" )
            license=rhel-7-sap-us
            ;;

        "1270685562947480748" )
            license=rhel-8-sap
            ;;

        "489291035512960571" )
            license=rhel-8-sap-byos
            ;;

        "8291906032809750558" )
            license=rhel-9-sap
            ;;

        "6753525580035552782" )
            license=rhel-9-sap-byos
            ;;
        * )
            license=""
            ;;

    esac

}

check_metadata_connectivity() {
    echo -e "\n######################## GCE Metadata server connectivity check ########################"
    if [ "$1" == "GCP" ]; then
        if curl -s "$Metadata_URL/computeMetadata/v1/instance/" \
                    -H "Metadata-Flavor: Google" | grep -q zone; then 
            echo "GCE Metadata connectivity check successful"
        else
            echo "GCE Metadata connectivity check failed!,\
                     Please check your instance health" 
        fi
    elif [ "$1" == "AWS" ]; then
        if curl -s "$Metadata_URL/latest/dynamic/instance-identity/document" |\
                                     grep -q "region"; then
            echo "AWS Metadata connectivity check successful"
        else
            echo "AWS Metadata connectivity check failed!"
            echo "Please check your instance health" 
        fi
    elif [ "$1" == "Azure" ]; then
        if curl -s "$Metadata_URL/metadata/instance?api-version=2021-02-01" \
                                    -H Metadata:true | grep -q "compute"; then
            echo "Azure Metadata connectivity check successful"
        else
            echo "Azure Metadata connectivity check failed!,\
                     Please check your instance health" 
        fi
    else
        platform="Unknown"
    fi
}
check_metadata_connectivity $platform

check_license() {
    echo -e "\n######################## PayG License check ########################"
    if [ "$1" == "GCP" ]; then
        rhel_payg_licenses=" 1176308840663243801 1000002 4646774207868449156 \
                1000006 601259152637613565 7883559014960410759 "
        rhel_sap_payg_licenses=" 8555687517154622919 5955710252559838163 \
                996690525257673675 1785892118823772022 5882583258875011738 \
                1270685562947480748 8291906032809750558 "
        licenses=$(curl -s \
                "$Metadata_URL/computeMetadata/v1/instance/licenses/?recursive=true"\
                                     -H "Metadata-Flavor: Google")
        for i in $(echo "$licenses" | grep -oP '"id":"\K[^"]+');
        do
            licnese_check $i
            #echo "License $license detected "
            if [[ "$rhel_payg_licenses " =~ " $i " ]]; then
                echo "RHEL PAYG License $license found. RHUI setup should work as expected"
                break
            elif [[ " $rhel_sap_payg_licenses" =~ " $i " ]]; then
                echo "RHEL-SAP PAYG License $license found. RHUI setup should work as expected"
                break
            else
                echo "RHEL PAYG License not found, RHUI will not work on this instance,"
                echo "unless you have your own RHEL Subscription"
            fi
        done

    elif [ "$1" == "AWS" ]; then
        pass
    elif [ "$1" == "Azure" ]; then
        pass
    else
        platform="Unknown"
    fi
}
check_license $platform

check_rhui_client() {
    echo -e "\n######################## RHUI package check ########################"
    rhui_client_rpm=$(rpm -qa google-rhui-client-rhel$os_major_version*)
    if [ -n "$rhui_client_rpm" ]; then
        rhui_client_rpm=${rhui_client_rpm%.noarch}
        if rpm -qa --changelog google-rhui-client-rhel$os_major_version*| grep -q RHUIv4; then
            echo "The RHUI client package $rhui_client_rpm"
        else
            echo -e "Your RHUI client package $rhui_client_rpm is obsolete and not compatible"
            echo " with latest Redhat Update Infrastructure v4"
            echo -e "Please plan to upgrade your google-rhui-client-rhel* package to latest one using command:"
            echo -e "   sudo yum update --repo google-compute-engine google-rhui-client-rhel$os_major_version*"
        fi
    else
        echo "RHUI Client package google-rhui-client-rhel* is missing from the instance."
        echo "Please install the latest RHUI client package based on your OS and licnese."
    fi

}
#check_rhui_client

check_rhui_v4_baseurls() {
    echo -e "\n######################## RHUIv4 mirrorURLs endpoint check ########################"
    if cat /etc/yum.repos.d/rh-cloud.repo | grep -v "^#" | grep -q "cds.rhel.updates.googlecloud.com"; then
        echo "You are still using RHUIv3 repo endpoints(https://cds.rhel.updates.googlecloud.com),"
        echo "which are now deprecated."
        check_rhui_client
    elif cat /etc/yum.repos.d/rh-cloud.repo | grep -v "^#" | grep -q "rhui.googlecloud.com"; then
        echo "Your yum repos are configured with correct RHUI endpoints(https://rhui.googlecloud.com)"
    fi
}
check_rhui_v4_baseurls

rhui_v4_endpoint_connectivity_check() {
    echo -e "\n######################## RHUIv4 endpoint connectivity check ########################"
    if curl -s https://rhui.googlecloud.com | grep -q "Red Hat"; 
    then
        echo "Connectivity to RHUIv4 endpoints(https://rhui.googlecloud.com) is working fine."
    else
        echo "Connectivity to RHUIv4 endpoints(https://rhui.googlecloud.com) is failing."
        echo "Please work with your Network team to allow communication to https://rhui.googlecloud.com"
    fi
}
rhui_v4_endpoint_connectivity_check

platform_related_repo_checks() {
    pass
}

http_error_checks() {
    echo -e "\n######################## HTTP error check in yum output ########################"
    yum repolist &> /tmp/rhui-temp 

    if cat /tmp/rhui-temp | egrep 'HTTPS Error|curl#'; then
        if cat /tmp/rhui-temp | egrep 'HTTPS Error|curl#'| awk -F "HTTPS Error|curl" '{print $NF}'| uniq| grep certificate;
        then
            echo "This can happen with an outdated google-rhui-client-rhelX or google-rhui-client-rhelX-sap*"
            echo "(X = RHEL version) package (containing outdated ssl certificates and keys required used"
            echo "to connect to rhui servers)."
        fi

        if cat /tmp/rhui-temp | egrep 'HTTPS Error|curl#'| awk -F "HTTPS Error|curl" '{print $NF}'| uniq| grep "404 - Not Found";
        then
            echo "The errors indicates a content mismatch between what you are asking for and"
            echo "what the RHUI contains. Please retry package install or update at different intervals."
            echo "If issue still persists, Please reachout to GCP Support via a case/chat"

        fi

        if cat /tmp/rhui-temp | egrep 'HTTPS Error|curl#'| awk -F "HTTPS Error|curl" '{print $NF}'| uniq| grep "403 - Forbidden";
        then
            echo "This issue can happen if the installed google-rhui-client is outdated"
            echo "and can be resolved by updating the rhui client package using yum."
            echo -e "  sudo yum update --repo google-compute-engine google-rhui-client-rhel$os_major_version* \n"
            echo "If issue still persists after updating the google-rhui-client to latest,"
            echo "Please reachout to GCP Support via a case/chat"
        fi
    else
        echo "No errors found in yum repolist output"
    fi
}
http_error_checks

check_yum_set_var() {
    echo -e "\n######################## check for releasever hardcoding ########################"
    # check for Version hardcoding
    releasever_file_name=$(grep -r releasever /etc/yum.conf /etc/yum/vars/| awk -F":" '{print $1}')
    releasever=$(grep -r releasever /etc/yum.conf /etc/yum/vars/| awk -F":" '{print $NF}')
    if [ -n "$releasever" ];
    then
        echo "yum releasever has been set to $releasever in $releasever_file_name."
        echo "This will restrict your instance to stay at same version until releasever"
        echo "config removed from the releasever_file_name"
    fi
}
check_yum_set_var
