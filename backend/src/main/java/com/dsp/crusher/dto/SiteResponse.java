package com.dsp.crusher.dto;

import lombok.Getter;
import lombok.Setter;
import java.time.LocalDateTime;

@Getter @Setter
public class SiteResponse {
    private Long id;
    private Long tenantId;
    private String name;
    private String location;
    private String siteType;
    private Long linkedPartyId;
    private String linkedPartyName;
    private String status;
    private LocalDateTime createdAt;
}
