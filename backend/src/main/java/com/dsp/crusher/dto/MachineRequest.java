package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.Getter;
import lombok.Setter;

@Getter @Setter
public class MachineRequest {
    @NotBlank @Pattern(regexp = "TENANT|VENDOR") private String owner;
    private Long vendorId;
    @NotBlank private String name;
    private String machineType;
}
