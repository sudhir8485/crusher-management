package com.dsp.crusher.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public class TenantProfileResponse {
    private Long id;
    private String name;
    private String address;
    private String phone;
    private String email;
    private String gstin;
    private String logoBase64;
}
