package com.dsp.crusher.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

@Getter @Setter
public class UserRequest {

    @NotBlank
    private String fullName;

    @NotBlank @Email
    private String email;

    private String password;       // required on create, optional on update (blank = keep existing)

    @NotNull
    private String role;           // OWNER_ADMIN | OFFICE_ACCOUNTANT | SITE_STAFF

    private Long siteId;           // required when role = SITE_STAFF
}
