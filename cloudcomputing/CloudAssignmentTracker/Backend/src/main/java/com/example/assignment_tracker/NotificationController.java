package com.example.assignment_tracker;

import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {

    private final NotificationService notificationService;
    private final NotificationSubscriberRepository subscriberRepository;
    private static final String MESSAGE = "message";

    public NotificationController(
            NotificationService notificationService,
            NotificationSubscriberRepository subscriberRepository) {

        this.notificationService = notificationService;
        this.subscriberRepository = subscriberRepository;
    }

    @PostMapping("/subscribe")
    public ResponseEntity<Map<String, String>> subscribe(
            @RequestBody Map<String, String> request) {

        String email = request.get("email");

        if (email == null || email.isBlank()) {
            return ResponseEntity.badRequest()
                    .body(Map.of(MESSAGE, "Email address is required."));
        }

        email = email.trim().toLowerCase();

        if (subscriberRepository.existsByEmail(email)) {
            return ResponseEntity.ok(
                    Map.of(MESSAGE, "This email is already subscribed."));
        }

        // Subscribe in SNS first, so a failed SNS call doesn't leave the
        // email saved as "already subscribed" when it isn't
        notificationService.subscribeEmail(email);

        NotificationSubscriber subscriber =
                new NotificationSubscriber(email);

        subscriberRepository.save(subscriber);

        return ResponseEntity.ok(
                Map.of(
                        MESSAGE,
                        "Check your email to confirm your subscription."));
    }
}