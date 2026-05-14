# Bootstrap

Run once per AWS account before the root config can use the S3 backend.

```bash
cd infra/bootstrap
terraform init
terraform apply
```

Outputs are referenced by ../backend.tf.
