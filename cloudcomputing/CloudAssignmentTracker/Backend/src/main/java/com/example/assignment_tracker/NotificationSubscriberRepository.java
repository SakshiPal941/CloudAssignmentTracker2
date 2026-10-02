package com.example.assignment_tracker;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

public interface NotificationSubscriberRepository
        extends JpaRepository<NotificationSubscriber, Long> {

    Optional<NotificationSubscriber> findByEmail(String email);

    boolean existsByEmail(String email);
}