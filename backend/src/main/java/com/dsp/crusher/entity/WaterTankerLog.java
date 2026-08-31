package com.dsp.crusher.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "water_tanker_logs")
@Getter @Setter
public class WaterTankerLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id", nullable = false)
    private Long tenantId;

    @Column(name = "log_date", nullable = false)
    private LocalDate logDate;

    @Column(name = "vehicle_id")
    private Long vehicleId;

    @Column(name = "hours_worked", precision = 8, scale = 2)
    private BigDecimal hoursWorked;

    @Column(name = "km_run", precision = 8, scale = 2)
    private BigDecimal kmRun;

    @Column(name = "trips_count")
    private Integer tripsCount;

    @Column(precision = 10, scale = 2)
    private BigDecimal rate;

    @Column(length = 500)
    private String notes;

    @Column(nullable = false, length = 20)
    private String status = "ACTIVE";

    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
}
