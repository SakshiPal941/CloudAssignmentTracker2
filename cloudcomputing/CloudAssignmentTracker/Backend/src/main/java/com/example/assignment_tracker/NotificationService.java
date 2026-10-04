package com.example.assignment_tracker;

import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Locale;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.sns.SnsClient;
import software.amazon.awssdk.services.sns.model.PublishRequest;

import software.amazon.awssdk.services.sns.model.SubscribeRequest;

@Service
public class NotificationService {

    private final SnsClient snsClient;

    @Value("${SNS_TOPIC_ARN}")
    private String topicArn;

    public NotificationService() {
        this.snsClient = SnsClient.builder()
                .region(Region.US_EAST_1)
                .credentialsProvider(DefaultCredentialsProvider.builder().build())
                .build();
    }

    public void sendDeadlineReminder(Assignment assignment) {

        LocalDate today = LocalDate.now(ZoneId.of("Pacific/Auckland"));
        String when = assignment.getDueDate().equals(today) ? "today" : "tomorrow";
        String dueDate = assignment.getDueDate()
                .format(DateTimeFormatter.ofPattern("EEEE d MMMM", Locale.ENGLISH));

        String course = assignment.getDescription();
        String courseLine = (course == null || course.isBlank()) ? "" : "Course: " + course + "\n";

        String message = "Hi there,\n\n"
                + "Just a reminder that \"" + assignment.getTitle() + "\" is due " + when + ".\n\n"
                + courseLine
                + "Due: " + dueDate + "\n\n"
                + "Good luck!\n"
                + "Assignment Tracker";

        // SNS subjects must be plain ASCII and at most 100 characters
        String subject = ("Due " + when + ": " + assignment.getTitle())
                .replaceAll("[^\\x20-\\x7E]", "");
        if (subject.length() > 100) {
            subject = subject.substring(0, 97) + "...";
        }

        PublishRequest request = PublishRequest.builder()
                .topicArn(topicArn)
                .subject(subject)
                .message(message)
                .build();

        snsClient.publish(request);
    }

    public void subscribeEmail(String email) {
    SubscribeRequest request = SubscribeRequest.builder()
            .topicArn(topicArn)
            .protocol("email")
            .endpoint(email)
            .build();

    snsClient.subscribe(request);
}
}