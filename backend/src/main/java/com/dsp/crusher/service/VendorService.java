package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.VendorRequest;
import com.dsp.crusher.entity.Vendor;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.VendorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class VendorService {

    private final VendorRepository repo;

    public List<Vendor> listActive() {
        return repo.findByStatus("ACTIVE");
    }

    public Vendor getById(Long id) {
        return repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Vendor not found: " + id));
    }

    @Transactional
    public Vendor create(VendorRequest req) {
        Vendor v = new Vendor();
        v.setTenantId(TenantContext.get());
        v.setName(req.getName());
        v.setGstin(req.getGstin());
        v.setContact(req.getContact());
        v.setAddress(req.getAddress());
        return repo.save(v);
    }

    @Transactional
    public Vendor update(Long id, VendorRequest req) {
        Vendor v = getById(id);
        v.setName(req.getName());
        v.setGstin(req.getGstin());
        v.setContact(req.getContact());
        v.setAddress(req.getAddress());
        return repo.save(v);
    }

    @Transactional
    public void deactivate(Long id) {
        Vendor v = getById(id);
        v.setStatus("INACTIVE");
        repo.save(v);
    }
}
