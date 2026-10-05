# Cloud Assignment Tracker

A web application for tracking university assignments and their due dates, with email reminders before each deadline when user subscribes.

- **Frontend**: plain HTML, CSS and JavaScript, served by Nginx
- **Backend**: Spring Boot (Java 17) REST API
- **Database**: PostgreSQL on Amazon RDS
- **Reminders**: Amazon SNS email notifications
- **Infrastructure**: Terraform, deployed to AWS `us-east-1`

## Architecture
The application is deployed using a VPC with separate public and private subnets. The frontend runs on a public EC2 instance and is accessed through the Internet. Nginx serves the frontend and proxies api requests to the backend. The backend runs on a private EC2 instance and connects to a private PostgreSQL database hosted on Amazon RDS. A NAT Gateway allows the backend to make outbound Internet connections without giving it a public IP address. Amazon SNS is used to send email reminders to confirmed subscribers.


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
### Prerequisites
1. An AWS account with access to the required AWS services. AWS Academy Learner Lab was used for this project.
2. AWS CLI installed and configured with the credentials provided by the Learner Lab.
3. Terraform installed.
4. Git installed.
5. The repository cloned locally.


### Steps
1. Start the AWS Academy Learner Lab and copy the AWS CLI credentials into the terminal.
2. Open a terminal in the Terraform folder:
3. cd cloudcomputing\CloudAssignmentTracker\terraform
4. Initialise Terraform: terraform init
5. Review the resources that Terraform will create: terraform plan
6. Deploy the infrastructure: terraform apply
7. Type yes when Terraform asks for confirmation.
8. Once deployment has finished, Terraform outputs the public IP address of the frontend. Open this address in a web browser to access the application.

The Terraform deployment creates the VPC, subnets, route tables, Internet Gateway, NAT Gateway, security groups, EC2 instances, RDS database and SNS topic in AWS. The EC2 user-data scripts then install the required software and start the application.


### Redeploying after a code change
The EC2 instances clone the repository when they are created. After making and pushing a code change, replace the relevant EC2 instance so that its startup script runs again and downloads the latest version:

terraform apply -replace="aws_instance.frontend" -replace="aws_instance.api"

If only the backend or frontend has changed, only the relevant instance needs to be replaced.


### Verifying the deployment

After deployment, the frontend can be checked by opening the public IP address in a browser. The deployment can also be checked using the provided script:
./scripts/check-deployment.sh
The script checks that the deployed application is responding correctly.

The API can also be tested directly using the frontend IP:
http://<frontend-public-ip>/api/assignments

This should return the assignments from the RDS database.

### Tearing down
To remove the AWS deployment, run terraform destroy from the terraform folder.

Then review the resources Terraform plans to remove and type yes to confirm.

This removes the infrastructure created by Terraform, including the EC2 instances, RDS instance, NAT Gateway, Elastic IP and networking resources. The current RDS configuration uses skip_final_snapshot = true, so destroying the RDS instance will also remove its database data unless it has been backed up separately first.

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

Run the one-time setup from the `Backend` folder:

```powershell
.\setup.ps1
```

This registers a global Git alias, so the backend can then be started from any folder in the repo:

```powershell
git run
```

The API starts on `http://localhost:8080`. The alias runs `mvnw.cmd spring-boot:run` in `Backend/`.

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
###Terraform cannot authenticate with AWS.
Make sure the AWS Academy Learner Lab is running and that the temporary AWS credentials from the Learner Lab have been added to the terminal. These credentials expire, so they may need to be replaced when starting a new lab session.

###The frontend does not load after terraform apply.
Check the public IP output by Terraform and make sure the frontend EC2 instance has finished running its startup script. The script installs Nginx and copies the frontend files into the Nginx web directory, so the instance may take a few minutes before the application is available.

###The backend is not responding.
Check that the backend EC2 instance has finished its startup process and that the API is running on port 8080. The backend is in a private subnet, so it cannot be accessed directly from the Internet. Requests should go through the frontend Nginx proxy using /api/.

###The backend cannot connect to AWS services or download packages during startup.
Check that the NAT Gateway is running and that the private application subnet is associated with the private route table. The backend uses the NAT Gateway for outbound Internet access while remaining private.


### Deployment
The application is deployed to AWS using Terraform. Running terraform apply creates the required AWS infrastructure, including the EC2 instances, RDS database, networking and SNS topic. The EC2 startup scripts then install the required software, download the latest code from the GitHub repository and start the application.

After deployment is complete, Terraform outputs the public IP address of the frontend EC2 instance. The application can then be accessed by entering this IP address into a web browser.


### App

**No reminder email arrives.**
Check that the subscription was confirmed from the AWS confirmation email, and check the spam folder. Reminders are only sent for assignments due today or tomorrow.

**`.\mvnw.cmd : The term '.\mvnw.cmd' is not recognized...`**
The `git run` alias was registered with the wrong path. Re-run `.\setup.ps1` from inside `Backend`. You can check the stored path with:

```powershell
git config --get alias.run
```
