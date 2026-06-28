output "ec2_instance_id" {
  value = aws_instance.viz.id
}

output "ec2_private_ip" {
  value = aws_instance.viz.private_ip
}

output "gold_loader_function_name" {
  value = aws_lambda_function.gold_loader.function_name
}

output "superset_ssm_tunnel" {
  description = "Run this, then open http://localhost:8088"
  value       = "aws ssm start-session --target ${aws_instance.viz.id} --document-name AWS-StartPortForwardingSession --parameters portNumber=8088,localPortNumber=8088 --region eu-central-1"
}
