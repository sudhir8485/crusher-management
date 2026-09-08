package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.util.List;

@Getter @Setter
public class MachineResponse {
    private Long id;
    private Long tenantId;
    private String owner;
    private Long vendorId;
    private String name;
    private String machineType;
    private String status;
    private Long linkedVehicleId;
    private String linkedVehicleName;
    private List<MachineWorkTypeDto> workTypes;
}
