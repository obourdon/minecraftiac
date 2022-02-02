terraform {
  backend "http" {
    address = "$(var.TF_VAR_terraform_state_url)"
    update_method = "PUT"
  }
}