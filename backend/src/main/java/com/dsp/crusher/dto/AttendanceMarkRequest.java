package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import java.time.LocalDate;

@Getter @Setter
public class AttendanceMarkRequest {

    @NotNull
    private LocalDate date;

    @NotNull
    private Long employeeId;

    @NotNull
    private String status;  // PRESENT | ABSENT | HALF_DAY | LEAVE

    private String notes;
}
