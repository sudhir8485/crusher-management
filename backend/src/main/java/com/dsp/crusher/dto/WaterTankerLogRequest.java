package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter @Setter
public class WaterTankerLogRequest {
    @NotNull private LocalDate logDate;
    @NotNull private Long vehicleId;
    private BigDecimal hoursWorked;
    private BigDecimal kmRun;
    private Integer tripsCount;
    private BigDecimal rate;
    private String notes;
}
