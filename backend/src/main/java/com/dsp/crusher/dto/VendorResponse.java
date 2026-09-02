package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter @Setter
public class VendorResponse {
    private Long id;
    private String name;
    private String gstin;
    private String contact;
    private String address;
    private String status;
    private BigDecimal outstandingAmount;
    private long unpaidInvoiceCount;
}
