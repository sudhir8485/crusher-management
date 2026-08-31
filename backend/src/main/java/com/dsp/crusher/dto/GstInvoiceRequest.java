package com.dsp.crusher.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Getter @Setter
public class GstInvoiceRequest {

    @NotNull
    private Long vendorId;

    @NotNull
    private LocalDate invoiceDate;

    private LocalDate supplyDate;
    private String poNo;

    private BigDecimal cgstRate = new BigDecimal("9.00");
    private BigDecimal sgstRate = new BigDecimal("9.00");

    @NotEmpty
    @Valid
    private List<GstInvoiceItemRequest> items;

    private String notes;
}
