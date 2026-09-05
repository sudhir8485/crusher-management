package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter @Setter
public class GstInvoiceItemRequest {

    @NotBlank
    private String description;

    private String hsn;

    private BigDecimal quantityBrass;

    private BigDecimal rate;

    @NotNull
    private BigDecimal amount;

    /** Optional — links this line item to a Material Master record for Recalculate GST. */
    private Long materialId;

    /** Optional — links this line item to a Service Master record (service/job-work lines). */
    private Long serviceId;
}
