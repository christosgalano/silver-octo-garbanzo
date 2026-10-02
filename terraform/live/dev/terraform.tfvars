project     = "acme"
environment = "dev"
owner       = "platform"
region      = "eu-central-1"

vpc_cidr = "10.10.0.0/16"
az_count = 2

# One private instance, so endpoints in one AZ are enough and halve the cost.
interface_endpoints_multi_az = false

instance_type = "t3.micro"
# World-open on purpose: this instance serves the public web on 80/443 only.
# Narrow it (e.g. an office /32) for any environment that isn't public-facing.
public_ingress_cidr = "0.0.0.0/0"

# Throwaway environment: let destroy clean up after itself.
artifacts_force_destroy = true
