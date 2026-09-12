package com.dsp.crusher.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;

@Getter @Setter
public class CreateTenantRequest {

    @NotBlank
    private String businessName;

    @NotBlank
    private String ownerFullName;

    @NotBlank @Email
    private String ownerEmail;

    @NotBlank
    private String ownerPassword;
}
