package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.ServiceRequest;
import com.dsp.crusher.entity.ServiceRecord;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.ServiceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ServiceMasterService {

    private final ServiceRepository repo;

    public List<ServiceRecord> listActive() {
        return repo.findByStatus("ACTIVE");
    }

    public ServiceRecord getById(Long id) {
        return repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Service not found: " + id));
    }

    @Transactional
    public ServiceRecord create(ServiceRequest req) {
        ServiceRecord s = new ServiceRecord();
        s.setTenantId(TenantContext.get());
        apply(s, req);
        return repo.save(s);
    }

    @Transactional
    public ServiceRecord update(Long id, ServiceRequest req) {
        ServiceRecord s = getById(id);
        apply(s, req);
        return repo.save(s);
    }

    @Transactional
    public void deactivate(Long id) {
        ServiceRecord s = getById(id);
        s.setStatus("INACTIVE");
        repo.save(s);
    }

    private void apply(ServiceRecord s, ServiceRequest req) {
        s.setName(req.getName());
        s.setCode(req.getCode());
        if (req.getDefaultUnit() != null) s.setDefaultUnit(req.getDefaultUnit());
        s.setDefaultRate(req.getDefaultRate());
        if (req.getGstRate() != null) {
            s.setGstRate(req.getGstRate());
            s.setGstRateConfigured(true);   // explicit save = deliberately configured
        }
        s.setSacCode(req.getSacCode());
    }
}
