package com.example.assignment_tracker;

import java.time.LocalDate;
import java.util.List;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

@Service
public class DeadlineNotificationService {

    private final AssignmentRepository assignmentRepository;
    private final NotificationService notificationService;

    public DeadlineNotificationService(
            AssignmentRepository assignmentRepository,
            NotificationService notificationService) {

        this.assignmentRepository = assignmentRepository;
        this.notificationService = notificationService;
    }

    @Scheduled(cron = "0 0 9 * * *", zone = "Pacific/Auckland")
    public void checkUpcomingDeadlines() {

        LocalDate tomorrow =
                LocalDate.now(java.time.ZoneId.of("Pacific/Auckland"))
                        .plusDays(1);

        List<Assignment> assignments =
                assignmentRepository.findByDueDate(tomorrow);

        for (Assignment assignment : assignments) {
            notificationService.sendDeadlineReminder(assignment);
        }
    }
}