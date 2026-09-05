package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter @Setter
public class JobWorkInvoiceItemRequest {
    /** Optional FK to Service Master — enables Recalculate GST action. */
    private Long serviceId;
    /** Snapshot description (e.g. service name) — stored as-is on the item. */
    private String description;
    private String sacCode;
    private BigDecimal quantity;
    private BigDecimal rate;
    private BigDecimal amount;
}
