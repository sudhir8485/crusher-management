package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.time.LocalDateTime;

@Getter @Setter
public class TenantListResponse {
    private Long id;
    private String name;
    private String status;
    private LocalDateTime createdAt;
    private String ownerName;
    private String ownerEmail;
}
