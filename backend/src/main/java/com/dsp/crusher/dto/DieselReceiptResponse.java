package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Getter @Setter
public class DieselReceiptResponse {
    private Long id;
    private LocalDate receiptDate;
    private String source;
    private BigDecimal quantityLiters;
    private BigDecimal ratePerLiter;
    private BigDecimal amount;
    private Long vendorId;
    private String vendorName;
    private String invoiceNo;
    private String notes;
    private LocalDateTime createdAt;
}
