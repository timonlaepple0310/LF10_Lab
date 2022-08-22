data "github_actions_public_key" "example_public_key" {
  repository = "LF10_Automatisierung"
}

resource "github_actions_secret" "example_secret" {
  repository       = "LF10_Automatisierung"
  secret_name      = "test"
  plaintext_value  = tls_private_key.rsa.private_key_pem
}
