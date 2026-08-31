package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;

@Getter @Setter
public class VendorRequest {
    @NotBlank private String name;
    private String gstin;
    private String contact;
    private String address;
}
