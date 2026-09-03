package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;

@Getter @Setter
public class VendorRequest {
    @NotBlank private String name;
    private String gstin;
    private Boolean gstRegistered;
    /** true = Regular (appears in Trip quick-select); false = Occasional. Independent of gstRegistered. */
    private Boolean isRegular;
    private String contact;
    private String address;
}
