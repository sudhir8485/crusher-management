package com.dsp.crusher.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;

@Getter @Setter
public class SiteRequest {
    @NotBlank private String name;
    private String location;
    /** OWN (default) | CLIENT_SITE */
    private String siteType;
    /** Required when siteType = CLIENT_SITE; ignored for OWN sites. */
    private Long linkedPartyId;
}
