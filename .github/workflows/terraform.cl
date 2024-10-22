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
  TF_VERSION: "1.3.5"
  AWS_REGION: "us-east-1"
  TERRAFORM_WORKING_DIR: "."

jobs:
  security_scan:
    name: 'Security Scan'
    runs-on: self-hosted
    permissions:
      id-token: write
      contents: read
      pull-requests: write
      security-events: write  # Required for GitHub Security tab

    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Install tfsec
      run: |
        curl -L "https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-linux-amd64" -o tfsec
        chmod +x tfsec
        sudo mv tfsec /usr/local/bin/
+       curl -sL "https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-linux-amd64" -o tfsec 
+       grep " tfsec-linux-amd64" tfsec-checksums.txt | sha256sum -c -
        chmod +x tfsec

    - name: Run tfsec
      id: tfsec
      run: |
        tfsec ${{ env.TERRAFORM_WORKING_DIR }} \
          --format sarif \
          --out tfsec.sarif \
          --soft-fail \
          --config-file ${{ env.TERRAFORM_WORKING_DIR }}/.tfsec.yml || true
        echo "TFSEC_OUTPUT<<EOF" >> $GITHUB_ENV
        cat tfsec.sarif >> $GITHUB_ENV
        echo "EOF" >> $GITHUB_ENV

    - name: Upload SARIF file
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: tfsec.sarif
        category: tfsec

    - name: Generate tfsec report
      if: github.event_name == 'pull_request'
      run: |
        TFSEC_OUTPUT=$(tfsec . --no-color --include-passed)
        echo "TFSEC_OUTPUT<<EOF" >> $GITHUB_ENV
        echo "$TFSEC_OUTPUT" >> $GITHUB_ENV
        echo "EOF" >> $GITHUB_ENV

    - name: Comment PR with tfsec results
      if: github.event_name == 'pull_request'
      uses: actions/github-script@v6
      with:
        script: |
          const tfsecOutput = process.env.TFSEC_OUTPUT;
          const comment = `### TFSec Security Scan Results
          \`\`\`
          ${tfsecOutput}
          \`\`\`
          `;
          
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: comment
          });

  terraform:
    name: 'Terraform Workflow'
    runs-on: self-hosted
    needs: security_scan
    
    permissions:
      id-token: write
      contents: read
      pull-requests: write

    steps:
    - name: Checkout code
      uses: actions/checkout@v3
      
    - name: Setup Terraform Cache
      uses: actions/cache@v3
      with:
        path: ~/.terraform.d/plugin-cache
        key: ${{ runner.os }}-terraform-${{ hashFiles('**/.terraform.lock.hcl') }}
        restore-keys: |
          ${{ runner.os }}-terraform-

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
        aws-region: ${{ env.AWS_REGION }}
        
    - name: Set up Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: ${{ env.TF_VERSION }}
        terraform_wrapper: false

    - name: Terraform Format Check
      run: terraform fmt -check -recursive
      working-directory: ${{ env.TERRAFORM_WORKING_DIR }}

    - name: Terraform Init
      run: terraform init -backend-config="key=terraform/state"
      working-directory: ${{ env.TERRAFORM_WORKING_DIR }}
      run: terraform init -backend-config="key=terraform/state"

    - name: Terraform Validate
      run: terraform validate
      working-directory: ${{ env.TERRAFORM_WORKING_DIR }}

    - name: Terraform Plan
      id: plan
      run: |
        terraform plan -out=tfplan -detailed-exitcode -no-color 2>&1 | tee plan.txt
        echo "PLAN_EXIT_CODE=$?" >> $GITHUB_ENV
      working-directory: ${{ env.TERRAFORM_WORKING_DIR }}
      continue-on-error: true

    - name: Update Pull Request
      uses: actions/github-script@v6
      if: github.event_name == 'pull_request'
      with:
        script: |
          const fs = require('fs');
          const plan = fs.readFileSync('${{ env.TERRAFORM_WORKING_DIR }}/plan.txt', 'utf8');
          const maxGitHubBodyLength = 65536;
          const truncatedPlan = plan.length > maxGitHubBodyLength 
            ? plan.substring(0, maxGitHubBodyLength) + '\n\n... Plan too long to display completely ...'
            : plan;
          
          const comment = `### Terraform Plan Output
          \`\`\`
          ${truncatedPlan}
          \`\`\`
          `;
          
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: comment
          });

    - name: Terraform Apply
      if: github.ref == 'refs/heads/main' && github.event_name == 'push'
      run: terraform apply -auto-approve tfplan
      working-directory: ${{ env.TERRAFORM_WORKING_DIR }}