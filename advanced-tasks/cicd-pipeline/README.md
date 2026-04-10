# CI/CD Pipeline

CodePipeline, CodeBuild, and CodeDeploy for rolling deployment to Auto Scaling Group.

## 1. Create Artifact Bucket

**Console:** S3 → Create bucket
- Name: `pipeline-artifacts-<account-id>`
- Region: us-east-1

## 2. IAM Roles

**Console:** IAM → Roles → Create role
- CodePipelineRole: CodePipeline + S3 access
- CodeBuildRole: CodeBuild + CloudWatchLogs access  
- CodeDeployRole: AWSCodeDeployRole managed policy

## 3. Create CodeBuild Project

**Console:** CodeBuild → Build projects → Create project
- Name: `app-build`
- Source: S3 bucket `pipeline-artifacts-<account-id>/source/app.zip`
- Environment: Linux, aws/codebuild/standard:5.0
- Buildspec: Use buildspec.yml from source
- Artifacts: S3 bucket `pipeline-artifacts-<account-id>/build/`

## 4. Create CodeDeploy Application

**Console:** CodeDeploy → Applications → Create application
- Name: `app-deploy`
- Compute platform: EC2/On-premises

**Console:** CodeDeploy → Applications → `app-deploy` → Create deployment group
- Name: `app-dg`
- Service role: CodeDeployRole
- Deployment type: In-place
- Environment: Auto Scaling group `app-asg`

## 5. Create Pipeline

**Console:** CodePipeline → Pipelines → Create pipeline
- Name: `app-pipeline`
- Service role: CodePipelineRole
- Artifact store: `pipeline-artifacts-<account-id>`

Stages:
1. **Source:** S3 → `pipeline-artifacts-<account-id>/source/app.zip`
2. **Build:** CodeBuild → `app-build`
3. **Deploy:** CodeDeploy → `app-deploy` / `app-dg`

## 6. Trigger Deployment

**Console:** S3 → Upload `app.zip` to `pipeline-artifacts-<account-id>/source/`

**Console:** CodePipeline → `app-pipeline` → Release change

## Cleanup

**Console:** CodePipeline → `app-pipeline` → Delete
**Console:** CodeDeploy → Applications → `app-deploy` → Delete
**Console:** CodeBuild → `app-build` → Delete
**Console:** S3 → Empty and delete bucket
