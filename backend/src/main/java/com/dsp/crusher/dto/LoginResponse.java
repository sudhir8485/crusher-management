package com.dsp.crusher.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public class LoginResponse {
    private String token;
    private String role;
    private String fullName;
    private Long tenantId;
    private Long siteId;      // null for admins; site assigned for SITE_STAFF
    private String tenantName; // business/company name for display and documents
}
