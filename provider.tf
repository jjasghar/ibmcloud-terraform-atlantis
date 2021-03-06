# variable "ibmcloud_api_key" {
#   description = "Enter your IBM Cloud API Key, you can get your IBM Cloud API key using: https://cloud.ibm.com/iam#/apikeys"
#   default = var.apikey
# }

provider "ibm" {
  ibmcloud_api_key      = var.apikey
  generation            = 2
  region                = "us-south"
}

