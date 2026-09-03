package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;

@Getter @Setter
public class VendorResponse {
    private Long id;
    private String name;
    private String gstin;
    private Boolean gstRegistered;
    private Boolean isRegular;
    private String contact;
    private String address;
    private String status;
    private BigDecimal outstandingAmount;
    private long unpaidInvoiceCount;
}
