package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter @Setter
public class MachineWorkLogResponse {

    private Long id;
    private LocalDate logDate;
    private Long machineId;
    private String machineName;
    private String machineType;
    private String workDescription;
    private String mode;
    private BigDecimal openingReading;
    private BigDecimal closingReading;
    private BigDecimal totalHours;
    private String notes;
    private String status;
}
