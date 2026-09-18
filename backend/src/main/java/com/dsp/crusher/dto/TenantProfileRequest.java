package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;

@Getter @Setter
public class TenantProfileRequest {
    private String name;
    private String address;
    private String phone;
    private String email;
    private String gstin;
    private String logoBase64;
    private String bankName;
    private String bankAccountNo;
    private String bankIfsc;
    private String invoicePrefix;
    private String invoiceTerms;
}
