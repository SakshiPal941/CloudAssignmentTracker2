resource "aws_sns_topic" "assignment_notifications" {
  name = "cloud-assignment-notifications"

  # Shown as the sender name on reminder emails instead of "AWS Notifications"
  display_name = "Assignment Tracker"
}