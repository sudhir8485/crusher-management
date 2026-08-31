package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.MaterialRequest;
import com.dsp.crusher.entity.Material;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.MaterialRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class MaterialService {

    private final MaterialRepository repo;

    public List<Material> listActive() {
        return repo.findByStatus("ACTIVE");
    }

    public Material getById(Long id) {
        return repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Material not found: " + id));
    }

    @Transactional
    public Material create(MaterialRequest req) {
        Material m = new Material();
        m.setTenantId(TenantContext.get());
        m.setName(req.getName());
        m.setSizeLabel(req.getSizeLabel());
        m.setUnit(req.getUnit());
        return repo.save(m);
    }

    @Transactional
    public Material update(Long id, MaterialRequest req) {
        Material m = getById(id);
        m.setName(req.getName());
        m.setSizeLabel(req.getSizeLabel());
        m.setUnit(req.getUnit());
        return repo.save(m);
    }

    @Transactional
    public void deactivate(Long id) {
        Material m = getById(id);
        m.setStatus("INACTIVE");
        repo.save(m);
    }
}
