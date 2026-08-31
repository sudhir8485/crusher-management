package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Getter @Setter
public class GstInvoiceResponse {
    private Long id;
    private Long vendorId;
    private String vendorName;
    private String vendorGstin;
    private String invoiceNo;
    private LocalDate invoiceDate;
    private LocalDate supplyDate;
    private String poNo;
    private BigDecimal cgstRate;
    private BigDecimal sgstRate;
    private BigDecimal subtotal;
    private BigDecimal cgstAmount;
    private BigDecimal sgstAmount;
    private BigDecimal grandTotal;
    private String notes;
    private String status;
    private List<GstInvoiceItemResponse> items;
}
