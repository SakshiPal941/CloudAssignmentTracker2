package com.example.assignment_tracker;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

// @EnableScheduling turns on the daily deadline reminder job in DeadlineNotificationService
@SpringBootApplication
@EnableScheduling
public class AssignmentTrackerApplication {

	public static void main(String[] args) {
		SpringApplication.run(AssignmentTrackerApplication.class, args);
	}

}
