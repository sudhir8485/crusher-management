package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter @Setter
public class MachineWorkLogRequest {

    @NotNull
    private LocalDate logDate;

    @NotNull
    private Long machineId;

    private String workDescription;

    @NotNull
    private String mode = "BUCKET";  // BUCKET | BREAKER

    private BigDecimal openingReading;
    private BigDecimal closingReading;
    private String notes;
}
