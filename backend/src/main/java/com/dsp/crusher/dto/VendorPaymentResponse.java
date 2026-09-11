package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Getter @Setter
public class VendorPaymentResponse {
    private Long id;
    private Long vendorId;
    private String vendorName;
    private Long invoiceId;
    private String invoiceNo;
    private LocalDate paymentDate;
    private BigDecimal amount;
    private String paymentMode;
    private String referenceNo;
    private String notes;
    private String status;
    private String allocationSummary;
    private String direction; // RECEIVED | PAID
    private Long transportPayableId;
    private LocalDateTime createdAt;
    private String createdByName;
    private String updatedByName;
}
