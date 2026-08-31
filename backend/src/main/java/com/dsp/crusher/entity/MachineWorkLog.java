package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "machine_work_logs")
@Getter @Setter
public class MachineWorkLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id", nullable = false)
    private Long tenantId;

    @Column(name = "log_date", nullable = false)
    private LocalDate logDate;

    @Column(name = "machine_id", nullable = false)
    private Long machineId;

    @Column(name = "work_description", length = 500)
    private String workDescription;

    @Column(nullable = false, length = 20)
    private String mode = "BUCKET";

    @Column(name = "opening_reading", precision = 10, scale = 2)
    private BigDecimal openingReading;

    @Column(name = "closing_reading", precision = 10, scale = 2)
    private BigDecimal closingReading;

    @Column(name = "total_hours", precision = 8, scale = 2)
    private BigDecimal totalHours;

    @Column(length = 500)
    private String notes;

    @Column(nullable = false, length = 20)
    private String status = "ACTIVE";

    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
}
