package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.LocalDate;

/** Per-party balance summary for the Accounts > Parties tab. */
@Getter @Setter
public class VendorBalanceResponse {
    private Long vendorId;
    private String name;
    private String contact;
    private String gstin;
    private Boolean gstRegistered;
    private Boolean isRegular;
    /** positive = party owes us (Outstanding), negative = we owe party (Advance), 0 = Settled. */
    private BigDecimal outstanding;
    private LocalDate lastActivityDate;
}
