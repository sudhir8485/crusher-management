package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import java.time.LocalDate;
import java.util.List;

@Getter @Setter
public class JobWorkInvoiceRequest {
    /** Client Site — party is auto-derived from site.linkedPartyId. */
    @NotNull private Long siteId;
    @NotNull private LocalDate invoiceDate;
    private String notes;
    @NotNull private List<JobWorkInvoiceItemRequest> items;
}
