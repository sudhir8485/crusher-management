package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter @Setter
public class DieselReceiptRequest {
    @NotNull private LocalDate receiptDate;
    @NotNull private String source;           // PUMP | DIRECT
    @NotNull private BigDecimal quantityLiters;
    private BigDecimal ratePerLiter;
    private Long vendorId;
    private String invoiceNo;
    private String notes;
}
