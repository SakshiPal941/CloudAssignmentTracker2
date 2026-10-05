# Cloud Assignment Tracker

A web application for tracking university assignments and their due dates, with email reminders before each deadline for users who subscribe.

- **Frontend**: plain HTML, CSS and JavaScript, served by Nginx
- **Backend**: Spring Boot (Java 17) REST API
- **Database**: PostgreSQL 17 on Amazon RDS
- **Reminders**: Amazon SNS email notifications
- **Infrastructure**: Terraform, deployed to AWS `us-east-1`

## Architecture

The application is deployed in a VPC with separate public and private subnets. The frontend runs on a public EC2 instance and is accessed through the Internet. Nginx serves the frontend and proxies API requests to the backend. The backend runs on a private EC2 instance and connects to a private PostgreSQL database hosted on Amazon RDS. A NAT Gateway allows the backend to make outbound Internet connections without giving it a public IP address. Amazon SNS sends email reminders to confirmed subscribers.

```
Internet
   | HTTP :80
Frontend EC2 (public subnet 10.0.1.0/24, Nginx)
   | /api/ proxied to 10.0.2.10:8080
Backend EC2 (private subnet 10.0.2.0/24) --> NAT Gateway --> Amazon SNS --> email
   | PostgreSQL :5432
RDS PostgreSQL (private subnets 10.0.3.0/24 and 10.0.4.0/24)
```

- **Trust boundary:** only the frontend is reachable from the Internet. The browser calls `/api/...` on the frontend, and Nginx forwards those requests to the backend.
- The backend accepts port 8080 only from the frontend's security group. The database accepts port 5432 only from the backend's security group, and is not publicly accessible.
- The backend has no public IP. It reaches the Internet (to clone the repository, download dependencies and call SNS) through a NAT Gateway.
- The backend gets its AWS permissions from the `LabInstanceProfile` instance profile, so no access keys are stored on the instance.

## Features

- Add, edit, complete and delete assignments. The list is sorted by due date.
- Each assignment has a title, a description, a due date and a status (`PENDING`, `IN_PROGRESS` or `COMPLETED`).
- Email reminders for upcoming deadlines.

### How reminders work

1. Enter an email address in the reminder signup inside the tracker card.
2. AWS sends a confirmation email to that address. No reminders arrive until the link in it is clicked.
3. Every day at 9:00am New Zealand time, the backend sends a reminder for each assignment due the next day.
4. An assignment added with a due date of today or tomorrow sends its reminder straight away, because the 9:00am job would otherwise miss it.

Reminders go to a single shared SNS topic, so every confirmed subscriber receives a reminder for every assignment. Emails arrive from the sender name "Assignment Tracker".

## Repository layout

The project lives in `cloudcomputing/CloudAssignmentTracker/`. All paths and commands in this README are relative to that folder.

| Path | Contents |
|---|---|
| `Backend/` | Spring Boot API, with the Maven wrapper |
| `Frontend/` | `index.html`, `app.js` and `style.css` |
| `terraform/` | All AWS infrastructure: VPC, subnets, security groups, EC2, RDS and SNS |
| `scripts/check-deployment.sh` | End-to-end check of a deployed app |
| `setup-database.sql` | Optional sample data for a local database |

## Deploying to AWS

### Prerequisites and versions

1. An AWS account with access to the required services. AWS Academy Learner Lab was used for this project.
2. AWS CLI, installed and configured with the Learner Lab credentials.
3. Terraform 1.16.4 (the version used) with the HashiCorp AWS provider `~> 6.0` (tested with 6.66.0). The configuration does not pin a Terraform version.
4. Git, and Bash to run the check script (Git Bash on Windows).
5. The repository cloned locally.
6. Region `us-east-1`. The database subnets are pinned to the zone IDs `use1-az1` and `use1-az2`.
7. An instance profile named `LabInstanceProfile` that allows SNS publish and subscribe. Learner Lab accounts already have it.

Resources are named with the prefix `cloud-assignment-` (for example `cloud-assignment-database`). Dependencies are not committed: Maven packages come from Maven Central, and the instances install OpenJDK 17 and Nginx from the Ubuntu 22.04 package repositories.

### Manual steps required

1. **Learner Lab credentials.** Start the lab and copy its AWS CLI credentials into your terminal. They are temporary and expire when the lab restarts, so they cannot be stored in the repository.
2. **`terraform.tfvars`.** Create it from the example and set `db_password` (at least 8 characters, and no `/`, `@`, `"` or spaces). Secrets must not be committed, so this file is git-ignored.
3. **Confirm the SNS subscription.** Each subscriber must click the link in the confirmation email, because AWS requires consent before sending.

### Steps

1. Push your changes to GitHub. Both EC2 instances clone the repository when they first boot, so they deploy what is on GitHub, not what is on your machine.
2. Start the Learner Lab and copy its credentials into your terminal.
3. Create your variables file and set `db_password`:

```bash
   cd cloudcomputing/CloudAssignmentTracker/terraform
   cp terraform.tfvars.example terraform.tfvars
```

4. Create the infrastructure, typing `yes` when asked:

```bash
   terraform init
   terraform plan
   terraform apply
```

5. Open the `frontend_public_ip` shown in the output in a browser, using `http://`.

Expected time: roughly 15 to 20 minutes for a from-scratch deployment (an estimate, not a measured figure). RDS creation and the backend's first build on a `t2.micro` take most of that. The page loads but shows no assignments until the build finishes.

Terraform creates the VPC, subnets, route tables, Internet Gateway, NAT Gateway, security groups, EC2 instances, RDS database and SNS topic. The EC2 user-data scripts then install the software and start the application.

### Redeploying after a code change

The instances only fetch the code when they are created. Push your change to GitHub, then replace the instance that changed:

```bash
terraform apply -replace=aws_instance.api        # backend
terraform apply -replace=aws_instance.frontend   # frontend
```

The backend keeps the same private IP, so the frontend does not need replacing when only the backend changes.

### Verifying the deployment

```bash
bash scripts/check-deployment.sh
```

The script reads the frontend IP from the Terraform output (or takes one as an argument). It checks that the page loads, the API is reachable through the proxy, and an assignment can be created, read, updated and deleted, then removes its test assignment. You can also open `http://<frontend-public-ip>/api/assignments` to see the data from RDS.

### Cost and tearing down

While running, the deployment costs about US$74 per month, mostly the NAT Gateway, EC2 and RDS. With the instances stopped it still costs about US$40 per month.

```bash
terraform destroy
```

Review the plan and type `yes`. This removes everything Terraform created. The RDS instance uses `skip_final_snapshot = true`, so its data is deleted unless you take a manual snapshot first.

## Running the backend locally

### Prerequisites

- Java 17 or later
- PostgreSQL running locally, with a database for this project
- No Maven install is needed; the wrapper in `Backend/` is used

### Configuration

The backend reads its settings from environment variables:

| Variable | Default | Notes |
|---|---|---|
| `DB_HOST` | `localhost` | |
| `DB_NAME` | `cosc349` | |
| `DB_USERNAME` | `postgres` | |
| `DB_PASSWORD` | `password` | |
| `SNS_TOPIC_ARN` | none | Required. The app will not start without it. |

`SNS_TOPIC_ARN` has no default. To work on the assignment features without AWS, set it to any placeholder value:

```powershell
$env:SNS_TOPIC_ARN = "arn:aws:sns:us-east-1:000000000000:local"
```

With a placeholder, assignments still save normally, but no emails are sent and the reminder signup returns an error. To test reminders locally, use the real topic ARN and have AWS credentials configured.

The tables are created automatically on startup. `setup-database.sql` loads sample assignments, and it clears the `assignments` table first.

### Starting the app

On Windows, run the one-time setup from the `Backend` folder:

```powershell
.\setup.ps1
```

This registers a global Git alias, so the backend can then be started from any folder in the repo:

```powershell
git run
```

The alias runs `mvnw.cmd spring-boot:run` in `Backend/`. On macOS or Linux, run this instead:

```bash
cd Backend
./mvnw spring-boot:run
```

The API starts on `http://localhost:8080`.

The frontend calls the API on relative `/api/...` paths, so opening `index.html` directly will not reach the backend. It needs a web server that proxies `/api/` to port 8080, as Nginx does in the deployment.

## API reference

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/assignments` | List all assignments, soonest due date first |
| `GET` | `/api/assignments/{id}` | Get one assignment |
| `POST` | `/api/assignments` | Create an assignment |
| `PUT` | `/api/assignments/{id}` | Update an assignment |
| `DELETE` | `/api/assignments/{id}` | Delete an assignment |
| `POST` | `/api/notifications/subscribe` | Subscribe an email address to reminders |

Assignment body:

```json
{
  "title": "COSC349 Assignment 2",
  "description": "Cloud Computing",
  "dueDate": "2026-10-05",
  "status": "PENDING"
}
```

Subscribe body:

```json
{ "email": "you@example.com" }
```

## Troubleshooting

**Terraform cannot authenticate with AWS.**
Make sure the AWS Academy Learner Lab is running and that the temporary AWS credentials from the Learner Lab have been added to the terminal. These credentials expire, so they may need to be replaced when starting a new lab session.

**The frontend does not load after `terraform apply`.**
Check the public IP output by Terraform and make sure the frontend EC2 instance has finished running its startup script. The script installs Nginx and copies the frontend files into the Nginx web directory, so it can take a few minutes before the application is available.

**The page loads but no assignments appear, or the API returns 502.**
The backend is probably still building, which takes several minutes on a `t2.micro`. Wait and run `scripts/check-deployment.sh` again. The backend is in a private subnet, so it cannot be reached directly; requests go through the frontend's Nginx proxy using `/api/`. If it does not recover, open the backend instance in the EC2 console and choose Actions > Monitor and troubleshoot > Get system log. The startup script writes its output there.

**The backend cannot connect to AWS services or download packages during startup.**
Check that the NAT Gateway is running and that the private application subnet is associated with the private route table. The backend uses the NAT Gateway for outbound Internet access while remaining private.

**`terraform apply` fails on the database subnet group.**
The database subnets are pinned to the zone IDs `use1-az1` and `use1-az2`, so the stack must be deployed in `us-east-1`.

**No reminder email arrives.**
Check that the subscription was confirmed from the AWS confirmation email, and check the spam folder. Reminders are only sent for assignments due today or tomorrow.

**`.\mvnw.cmd : The term '.\mvnw.cmd' is not recognized...`**
The `git run` alias was registered with the wrong path. Re-run `.\setup.ps1` from inside `Backend`. You can check the stored path with:

```powershell
git config --get alias.run
```

## Credits

Spring Boot, Spring Data JPA, the AWS SDK for Java v2 (SNS), PostgreSQL JDBC, Lombok, Terraform with the HashiCorp AWS provider, Nginx and OpenJDK. 
