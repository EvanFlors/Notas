# Config del backend. Para MODE=local coincide con lo que crea bootstrap-backend.sh.
# Para MODE=live, edita bucket/dynamodb_table a los valores reales de tu cuenta.
bucket         = "tf-state-tf11"
key            = "tf-11-01/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "tf-lock-tf11"
encrypt        = true

# Flags necesarios para hablar con localstack (ignorados sin daño contra AWS real
# salvo force_path_style, que en live puedes dejar en true sin romper nada).
skip_credentials_validation = true
skip_metadata_api_check     = true
skip_requesting_account_id  = true
force_path_style            = true
