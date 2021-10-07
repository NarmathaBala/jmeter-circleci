variable "RESOURCE_GROUP_NAME" {
  type    = string
  default = "jmeter"
}

variable "LOCATION" {
  type    = string
  default = "eastus"
}

variable "PREFIX" {
  type    = string
  default = "jmeter"
}

variable "VNET_ADDRESS_SPACE" {
  type    = string
  default = "10.0.0.0/16"
}

variable "SUBNET_ADDRESS_PREFIX" {
  type    = string
  default = "10.0.0.0/24"
}

variable "VM_SUBNET_ADDRESS_PREFIX" {
  type    = string
  default = "10.0.1.0/24"
}

variable "JMETER_SLAVES_COUNT" {
  type    = number
  default = 1
}

variable "JMETER_SLAVE_CPU" {
  type    = string
  default = "2.0"
}

variable "JMETER_SLAVE_VM_SKU" {
  type    = string
  default = "Standard_F2"
}

variable "JMETER_SLAVE_VM_PASS" {
  type    = string
}

variable "JMETER_SLAVE_VM_ROLE_ASSIGNMENT_NAME_PREFIX" {
  type    = string
  default = "F57CBBC8-BDE5-4191-913D-B9E"
}


variable "JMETER_SLAVE_MEMORY" {
  type    = string
  default = "8.0"
}

variable "JMETER_MASTER_CPU" {
  type    = string
  default = "2.0"
}

variable "JMETER_MASTER_MEMORY" {
  type    = string
  default = "8.0"
}

variable "JMETER_DOCKER_IMAGE" {
  type    = string
  default = "justb4/jmeter:5.1.1"
}

variable "JMETER_DOCKER_PORT" {
  type    = number
  default = 1099
}

variable "JMETER_IMAGE_REGISTRY_SERVER" {
  type    = string
  default = ""
}

variable "JMETER_IMAGE_REGISTRY_USERNAME" {
  type    = string
  default = ""
}

variable "JMETER_IMAGE_REGISTRY_PASSWORD" {
  type    = string
  default = ""
}

variable "JMETER_STORAGE_QUOTA_GIGABYTES" {
  type    = number
  default = 1
}

variable "JMETER_JMX_FILE" {
  type        = string
  default     = "sample.jmx"
  description = "JMX file"
}

variable "JMETER_RESULTS_FILE" {
  type    = string
  default = "results.jtl"
}

variable "JMETER_DASHBOARD_FOLDER" {
  type    = string
  default = "dashboard"
}
