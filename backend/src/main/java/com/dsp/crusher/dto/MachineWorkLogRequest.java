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

    private String mode;         // free-form label from selected work type; null when machine has no work types

    private Long workTypeId;     // FK to machine_work_types; null when machine has no work types

    private BigDecimal openingReading;
    private BigDecimal closingReading;
    private String notes;

    private String workPurpose = "INTERNAL";   // INTERNAL | CUSTOMER_BILLABLE
    private Long customerId;
    private BigDecimal rate;     // null = save as PENDING (no Work Type default was available/used)
}
