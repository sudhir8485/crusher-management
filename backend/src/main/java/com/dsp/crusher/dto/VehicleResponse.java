package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;

@Getter @Setter
public class VehicleResponse {
    private Long id;
    private Long tenantId;
    private String owner;
    private Long vendorId;
    private String plateNumber;
    private String displayName;
    private String vehicleType;
    private String status;
    private Long linkedMachineId;
    private String linkedMachineName;
}
