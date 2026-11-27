## AWS CSPM Auto-Remediation Bot

An event-driven AWS security automation pipeline that detects cloud misconfigurations, notifies security engineers through Slack, and enables **approved, one-click remediation** with an auditable trail.

## The Problem

Cloud security tools can identify misconfigurations, but fixing them often requires manually reviewing alerts, navigating the AWS Console, and applying changes. This creates operational friction, alert fatigue, and delays in remediation.

## What I Built

I built a serverless, Human-in-the-Loop (HITL) remediation workflow that connects AWS Security Hub to Slack, allowing security engineers to respond to security findings without manually navigating AWS for every remediation.

The workflow automates:

**Detect → Notify → Approve → Remediate → Audit**

## Architecture

- **AWS Security Hub** detects security findings.
- **Amazon EventBridge** routes relevant HIGH and CRITICAL findings.
- **AWS Lambda (`notify.py`)** processes findings and sends interactive Slack alerts.
- **Slack** provides `Fix` and `Ignore` actions for human approval.
- **Amazon API Gateway** receives Slack interaction callbacks.
- **AWS Lambda (`remediate.py`)** performs approved remediation actions.
- **Amazon S3** stores remediation audit records.

## Tech Stack

| Technology | Purpose |
|---|---|
| Terraform | Infrastructure as Code |
| AWS Lambda | Serverless automation |
| Python 3.12 | Remediation and event processing |
| AWS Security Hub | Security findings |
| Amazon EventBridge | Event routing |
| API Gateway | Slack interaction endpoint |
| Amazon S3 | Audit trail storage |
| IAM | Least-privilege permissions |
| Slack API | Alerts and approval workflow |

## Security Principles

- Human approval before remediation
- Least-privilege IAM permissions
- Event-driven architecture
- Auditable remediation actions
- Serverless infrastructure

## What This Project Demonstrates

- Building event-driven security automation on AWS
- Integrating AWS security services with external platforms
- Implementing Human-in-the-Loop workflows
- Automating cloud security remediation
- Infrastructure provisioning with Terraform
- Designing security workflows with accountability and auditability

## Deployment

### Prerequisites

- AWS CLI configured
- Terraform installed
- Slack workspace and Slack App configured with webhook and interactivity permissions

### Deploy

```bash
git clone https://github.com/0xZeteo/cspm-remediation-bot.git

cd cspm-remediation-bot
