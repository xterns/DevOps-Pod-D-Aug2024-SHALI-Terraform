name: Terraform CI/CD Pipeline

on:
  push:
    branches:
      - main
      - feature/*
    paths:
      - 'Environments/prod/**'
      - '.github/workflows/**'
      - '*.tf'
      - '**.tfvars'
  pull_request:
    branches:
      - main
      - feature/*
    paths:
      - 'Environments/prod/**'
      - '.github/workflows/**'
      - '*.tf'
      - '**.tfvars'

env:
  TF_VERSION: "1.5.7"
  AWS_REGION: "us-east-1"
  TERRAFORM_WORKING_DIR: "./Environments/prod"
  TFSEC_VERSION: "v1.28.4"

jobs:
  security_scan:
    name: 'Security Scan'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      security-events: write

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Install tfsec
      run: |
        wget -q -O tfsec "https://github.com/aquasecurity/tfsec/releases/download/${{ env.TFSEC_VERSION }}/tfsec-linux-amd64"
        chmod +x tfsec
        sudo mv tfsec /usr/local/bin/

    - name: Run tfsec
      run: |
        tfsec ${{ env.TERRAFORM_WORKING_DIR }} \
          --format sarif \
          --out tfsec.sarif \
          --minimum-severity HIGH

    - name: Upload SARIF file
      uses: github/codeql-action/upload-sarif@v3
      with:
        sarif_file: tfsec.sarif
        category: tfsec

  terraform:
    name: 'Terraform Workflow'
    needs: security_scan
    runs-on: ubuntu-latest
    
    permissions:
      contents: read
      pull-requests: write
      id-token: write
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}
        terraform_wrapper: false

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
        aws-region: ${{ env.AWS_REGION }}
        role-duration-seconds: 1200

    - name: Setup Terraform Cache
      uses: actions/cache@v4
      with:
        path: ~/.terraform.d/plugin-cache
        key: ${{ runner.os }}-terraform-${{ hashFiles('**/.terraform.lock.hcl') }}
        restore-keys: |
          ${{ runner.os }}-terraform-

    - name: Terraform Format Check
      id: fmt
      run: terraform fmt -check -recursive -diff
      working-directory: ${{ env.TERRAFORM_WORKING_DIR }}

    - name: Terraform Init
      id: init
      run: terraform init -backend-config="key=terraform/state"
      working-directory: ${{ env.TERRAFORM_WORKING_DIR }}

    - name: Terraform Validate
      id: validate
      run: terraform validate -no-color
      working-directory: ${{ env.TERRAFORM_WORKING_DIR }}

    - name: Terraform Plan
      id: plan
      if: github.event_name == 'pull_request'
      run: |
        terraform plan -no-color -input=false -out=tfplan 2>&1 | tee plan.txt
      working-directory: ${{ env.TERRAFORM_WORKING_DIR }}

    - name: Post Terraform Plan
      if: github.event_name == 'pull_request'
      uses: actions/github-script@v7
      with:
        script: |
          const fs = require('fs');
          const { promisify } = require('util');
          const readFile = promisify(fs.readFile);

          async function postPlan() {
            const planContent = await readFile('${{ env.TERRAFORM_WORKING_DIR }}/plan.txt', 'utf8');
            const maxLength = 65000;

            let comment = '### Terraform Plan Summary\n\n';

            if (Buffer.byteLength(planContent, 'utf8') > maxLength) {
              const truncatedBuf = Buffer.alloc(maxLength);
              Buffer.from(planContent).copy(truncatedBuf, 0, 0, maxLength);
              comment += '```diff\n' + truncatedBuf.toString('utf8') + '\n...[Plan output truncated]...\n```';
            } else {
              comment += '```diff\n' + planContent + '\n```';
            }

            await github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: comment
            });
          }

          await postPlan();

    - name: Terraform Plan (main branch)
      id: plan-main
      if: github.ref == 'refs/heads/main' && github.event_name == 'push'
      run: |
        terraform plan -no-color -input=false -out=tfplan
      working-directory: ${{ env.TERRAFORM_WORKING_DIR }}

    - name: Manual Approval
      if: github.event_name == 'push' && github.ref == 'refs/heads/main'
      id: approval
      uses: trstringer/manual-approval@v1
      with:
        approvers: darey-io, uzukwujp
        secret: ${{ secrets.GITHUB_TOKEN }}
        minimum-approvals: 1
        issue-title: "Manual approval required for Terraform pipeline"
        issue-body: |
          Workflow is pending manual review.
          URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
          Required approvers: [darey-io, uzukwujp]
          Respond "approved", "approve", "lgtm", "yes" to continue workflow or "denied", "deny", "no" to cancel

    - name: Terraform Apply
      if: github.ref == 'refs/heads/main' && github.event_name == 'push'
      run: |
        terraform apply -auto-approve tfplan
      working-directory: ${{ env.TERRAFORM_WORKING_DIR }}
