# The environment root is configuration only: backend, provider and one call to
# the stack. Anything that is not a per-environment value belongs in the stack.

module "base" {
  source = "../../stacks/base"

  name                         = "${var.project}-${var.environment}"
  vpc_cidr                     = var.vpc_cidr
  az_count                     = var.az_count
  interface_endpoints_multi_az = var.interface_endpoints_multi_az
  instance_type                = var.instance_type
  public_ingress_cidr          = var.public_ingress_cidr
  artifacts_force_destroy      = var.artifacts_force_destroy
}
