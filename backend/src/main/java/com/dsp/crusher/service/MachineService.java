package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.MachineRequest;
import com.dsp.crusher.entity.Machine;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.MachineRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class MachineService {

    private final MachineRepository repo;

    public List<Machine> listActive() {
        return repo.findByStatus("ACTIVE");
    }

    public Machine getById(Long id) {
        return repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Machine not found: " + id));
    }

    @Transactional
    public Machine create(MachineRequest req) {
        Machine m = new Machine();
        m.setTenantId(TenantContext.get());
        m.setOwner(req.getOwner());
        m.setVendorId(req.getVendorId());
        m.setName(req.getName());
        m.setMachineType(req.getMachineType());
        return repo.save(m);
    }

    @Transactional
    public Machine update(Long id, MachineRequest req) {
        Machine m = getById(id);
        m.setOwner(req.getOwner());
        m.setVendorId(req.getVendorId());
        m.setName(req.getName());
        m.setMachineType(req.getMachineType());
        return repo.save(m);
    }

    @Transactional
    public void deactivate(Long id) {
        Machine m = getById(id);
        m.setStatus("INACTIVE");
        repo.save(m);
    }
}
