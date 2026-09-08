package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Getter @Setter
public class MachineWorkLogResponse {

    private Long id;
    private LocalDate logDate;
    private Long machineId;
    private String machineName;
    private String machineType;
    private String workDescription;
    private String mode;
    private Long workTypeId;
    private BigDecimal openingReading;
    private BigDecimal closingReading;
    private BigDecimal totalHours;
    private String notes;
    private String status;

    // ── Customer Billable ─────────────────────────────────────────────────────

    private String workPurpose;
    private Long customerId;
    private String customerName;
    private BigDecimal rate;
    private String rateStatus;       // PENDING | SET | null
    private BigDecimal totalAmount;
    private String rateSetBy;
    private LocalDateTime rateSetAt;

    private Long gstInvoiceId;
    private String gstInvoiceStatus;  // PENDING | SET | null
}
