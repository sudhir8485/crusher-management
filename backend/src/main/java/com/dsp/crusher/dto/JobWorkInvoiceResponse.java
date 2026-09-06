package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Getter @Setter
public class JobWorkInvoiceResponse {
    private Long id;
    private Long vendorId;
    private String vendorName;
    private String vendorGstin;
    private Long siteId;
    private String siteName;
    private String invoiceNo;
    private LocalDate invoiceDate;
    private LocalDate periodFrom;
    private LocalDate periodTo;
    private BigDecimal cgstRate;
    private BigDecimal sgstRate;
    private BigDecimal subtotal;
    private BigDecimal cgstAmount;
    private BigDecimal sgstAmount;
    private BigDecimal grandTotal;
    private String notes;
    private String status;
    private String gstStatus;
    private String gstRecalculatedBy;
    private LocalDateTime gstRecalculatedAt;
    private BigDecimal gstPrevSgstRate;
    private BigDecimal gstPrevCgstRate;
    private List<JobWorkInvoiceItemResponse> items;
}
