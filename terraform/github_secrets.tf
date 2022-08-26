data "github_actions_public_key" "example_public_key" {
  repository = "LF10_Automatisierung"
  key_id = "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"
}

resource "github_actions_secret" "example_secret" {
  repository       = "LF10_Automatisierung"
  secret_name      = "SSH_PRIVATE_KEY"
  plaintext_value  = tls_private_key.rsa.private_key_pem
}
