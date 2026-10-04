package com.example.assignment_tracker;
 
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

@Service
public class AssignmentService {

    private static final Logger log = LoggerFactory.getLogger(AssignmentService.class);

    @Autowired
    private AssignmentRepository assignmentRepository;

    @Autowired
    private NotificationService notificationService;
 
    public List<Assignment> getAllAssignments() {
        return assignmentRepository.findAllByOrderByDueDateAsc();
    }
 
    public Optional<Assignment> getAssignmentById(Long id) {
        return assignmentRepository.findById(id);
    }
 
    public Assignment createAssignment(Assignment assignment) {
        Assignment saved = assignmentRepository.save(assignment);

        // The daily 9am job would miss an assignment added today that is due
        // today or tomorrow, so send its reminder straight away
        LocalDate today = LocalDate.now(ZoneId.of("Pacific/Auckland"));
        LocalDate due = saved.getDueDate();
        if (due != null && !due.isBefore(today) && !due.isAfter(today.plusDays(1))) {
            try {
                notificationService.sendDeadlineReminder(saved);
            } catch (Exception e) {
                // A failed email shouldn't stop the assignment being saved
                log.warn("Could not send reminder for assignment {}", saved.getId(), e);
            }
        }

        return saved;
    }
 
    public Optional<Assignment> updateAssignment(Long id, Assignment updated) {
        return assignmentRepository.findById(id).map(existing -> {
            existing.setTitle(updated.getTitle());
            existing.setDescription(updated.getDescription());
            existing.setDueDate(updated.getDueDate());
            existing.setStatus(updated.getStatus());
            return assignmentRepository.save(existing);
        });
    }
 
    public boolean deleteAssignment(Long id) {
        if (!assignmentRepository.existsById(id)) {
            return false;
        }
        assignmentRepository.deleteById(id);
        return true;
    }
}