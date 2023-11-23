terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.26.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

#roles

resource "aws_iam_instance_profile" "test_profile" {
  name = "test_profile"
  role = aws_iam_role.example.name
}

resource "aws_iam_role" "example" {
  name = "example-role"

  assume_role_policy = jsonencode({
  Version: "2012-10-17",
  Statement: [
    {
    Action: "sts:AssumeRole",
    Effect: "Allow",
    Principal: {
    Service: [
        "ec2.amazonaws.com",
        "codebuild.amazonaws.com",
        "elasticbeanstalk.amazonaws.com",
        "codepipeline.amazonaws.com"]
    }      
    },
  ]
})
    managed_policy_arns = [
    "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier",
    "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker",
    "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier",
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
  ]

}

#s3 bucket

resource "aws_s3_bucket" "artifacts" {
  bucket = "codepipeline-artifacts-bucket2023-1"
}


#codebuild

# CodeBuild Project

resource "aws_codebuild_project" "example" {
  name = "codebuild-project"

  source {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  service_role = aws_iam_role.example.arn
}

# CodePipeline

resource "aws_codestarconnections_connection" "example" {
  name          = "example-connection"
  provider_type = "Bitbucket"
}

resource "aws_codepipeline" "example" {
  name     = "tf-test-pipeline"
  
  role_arn = aws_iam_role.example.arn

artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }
  
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.example.arn
        FullRepositoryId = "impuls666/react-btc"
        BranchName       = "main"
      }
    }
  }
    stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = "test"
      }
    }
  }
}




#elastic
resource "aws_elastic_beanstalk_application" "example" {
  name        = "eb-application"
  description = "Elastic Beanstalk Application Example"
}

resource "aws_elastic_beanstalk_environment" "example" {
  name        = "eb-environment"
  application = aws_elastic_beanstalk_application.example.name
  solution_stack_name = "64bit Amazon Linux 2023 v6.0.3 running Node.js 18"
  setting {
    namespace = "aws:autoscaling:launchconfiguration" # Define namespace
    name      = "IamInstanceProfile"                  # Define name
    value     = "test_profile"       # Define value
  }   


}
