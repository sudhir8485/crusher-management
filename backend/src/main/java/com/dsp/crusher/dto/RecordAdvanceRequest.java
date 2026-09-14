package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter @Setter
public class RecordAdvanceRequest {

    @NotNull
    private Long employeeId;

    @NotNull
    private LocalDate date;

    @NotNull
    @Positive
    private BigDecimal amount;

    private String notes;

    private String paymentType   = "ADVANCE";  // ADVANCE | SALARY
    private String paymentMethod = "CASH";      // CASH | BANK_TRANSFER | UPI | OTHER
}
