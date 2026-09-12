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
}
