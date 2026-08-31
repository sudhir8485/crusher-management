package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.Getter;
import lombok.Setter;

@Getter @Setter
public class VehicleRequest {
    @NotBlank @Pattern(regexp = "TENANT|VENDOR") private String owner;
    private Long vendorId;
    @NotBlank private String plateNumber;
    private String displayName;
    private String vehicleType;
}
