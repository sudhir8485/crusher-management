package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Getter @Setter
public class WaterTankerLogResponse {
    private Long id;
    private LocalDate logDate;
    private Long vehicleId;
    private String vehicleDisplayName;
    private String vehiclePlateNumber;
    private BigDecimal hoursWorked;
    private BigDecimal kmRun;
    private Integer tripsCount;
    private BigDecimal rate;
    private BigDecimal amount;   // computed: hoursWorked * rate (or tripsCount * rate)
    private String notes;
    private LocalDateTime createdAt;
}
