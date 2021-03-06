locals {
  jenkins_job_name = "jenkins-example"
  volume_name = "jenkins_home"
  jenkins_jobspec_variables = {
    job_name = local.jenkins_job_name
    datacenters = var.nomad_datacenters
    volume_name = local.volume_name
  }
  jenkins_jobspec_rendered = templatefile("${path.module}/templates/jenkins.nomad.hcl.tpl", local.jenkins_jobspec_variables)
}

resource "aws_efs_file_system" "nomad" {}

resource "aws_efs_mount_target" "nomad_efs" {
  for_each       = var.subnet_ids
  file_system_id = aws_efs_file_system.nomad.id
  subnet_id      = each.value
  security_group = [ aws_security_group.efs ]
}

resource "aws_security_group" "efs" {
  name        = "allow_nfs"
  description = "Allow NFS inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

module "aws_efs_csi_plugin" {
  source  = "KristophUK/aws-efs-csi-plugin/nomad"
  version = "0.1.1"
}

data "nomad_plugin" "aws_efs" {
  plugin_id        = module.aws_efs_csi_plugin.plugin_id
  wait_for_healthy = true
}

resource "nomad_volume" "job_volume" {
  depends_on      = [ data.nomad_plugin.aws_efs ]
  type            = "csi"
  plugin_id       = module.aws_efs_csi_plugin.plugin_id
  volume_id       = local.volume_name
  name            = local.volume_name
  external_id     = aws_efs_file_system.nomad.id
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}

resource "nomad_job" "jenkins" {

}