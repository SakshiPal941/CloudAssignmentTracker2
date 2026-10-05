# Cloud Assignment Tracker

A web application for tracking university assignments and their due dates, with email reminders before each deadline when user subscribes.

- **Frontend**: plain HTML, CSS and JavaScript, served by Nginx
- **Backend**: Spring Boot (Java 17) REST API
- **Database**: PostgreSQL on Amazon RDS
- **Reminders**: Amazon SNS email notifications
- **Infrastructure**: Terraform, deployed to AWS `us-east-1`

## Architecture


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



### Steps


### Redeploying after a code change



### Verifying the deployment


### Tearing down



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

### Deployment


### App

**No reminder email arrives.**
Check that the subscription was confirmed from the AWS confirmation email, and check the spam folder. Reminders are only sent for assignments due today or tomorrow.

**`.\mvnw.cmd : The term '.\mvnw.cmd' is not recognized...`**
The `git run` alias was registered with the wrong path. Re-run `.\setup.ps1` from inside `Backend`. You can check the stored path with:

```powershell
git config --get alias.run
```
