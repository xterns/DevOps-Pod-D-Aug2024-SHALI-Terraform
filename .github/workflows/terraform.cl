name: Terraform CI/CD Pipeline

on:
  push:
    branches:
      - main
      - 'feature/*'
  pull_request:
    branches:
      - main
      - 'feature/*'

env:
  TF_VERSION: "1.5.7"  # Updated to a more recent version
  AWS_REGION: "us-east-1"
  TERRAFORM_WORKING_DIR: "."
  TFSEC_VERSION: "v1.28.4"  # Explicitly specify tfsec version

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

    - name: Post tfsec findings
      if: github.event_name == 'pull_request'
      uses: actions/github-script@v7
      with:
        script: |
          const fs = require('fs');
          const sarif = JSON.parse(fs.readFileSync('tfsec.sarif', 'utf8'));
          const findings = sarif.runs[0].results;
          
          if (findings.length === 0) {
            const comment = '### ✅ TFSec Security Scan: No issues found';
            await github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: comment
            });
            return;
          }
          
          let comment = '### ⚠️ TFSec Security Scan Results\n\n';
          findings.forEach(finding => {
            comment += `- **${finding.level}**: ${finding.message.text}\n`;
            comment += `  - Location: ${finding.locations[0].physicalLocation.artifactLocation.uri}\n`;
            comment += `  - Rule: ${finding.ruleId}\n\n`;
          });
          
          await github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: comment
          });

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
          const plan = fs.readFileSync('${{ env.TERRAFORM_WORKING_DIR }}/plan.txt', 'utf8');
          const maxLength = 65000; // GitHub has a comment size limit
          
          let comment = '### Terraform Plan Summary\n\n';
          
          if (plan.length > maxLength) {
            comment += '```diff\n' + plan.slice(0, maxLength) + '\n...[Plan output truncated]...\n```';
          } else {
            comment += '```diff\n' + plan + '\n```';
          }
          
          await github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: comment
          });

    - name: Terraform Plan (main branch)
      id: plan-main
      if: github.ref == 'refs/heads/main' && github.event_name == 'push'
      run: |
        terraform plan -no-color -input=false -out=tfplan
      working-directory: ${{ env.TERRAFORM_WORKING_DIR }}

    - name: Terraform Apply
      if: github.ref == 'refs/heads/main' && github.event_name == 'push'
      run: |
        terraform apply -auto-approve tfplan
      working-directory: ${{ env.TERRAFORM_WORKING_DIR }}
