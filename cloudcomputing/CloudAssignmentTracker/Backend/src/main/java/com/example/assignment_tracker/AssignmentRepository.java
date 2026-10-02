package com.example.assignment_tracker;
 
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
 
public interface AssignmentRepository extends JpaRepository<Assignment, Long> {
 
    // returns all assignments ordered by closest deadline first
    List<Assignment> findAllByOrderByDueDateAsc();

        // returns assignments due on a specific date
    List<Assignment> findByDueDate(LocalDate dueDate);

}
 