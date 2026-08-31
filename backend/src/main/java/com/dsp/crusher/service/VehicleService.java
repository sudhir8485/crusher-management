package com.dsp.crusher.service;

import com.dsp.crusher.config.TenantContext;
import com.dsp.crusher.dto.VehicleRequest;
import com.dsp.crusher.entity.Vehicle;
import com.dsp.crusher.exception.ResourceNotFoundException;
import com.dsp.crusher.repository.VehicleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class VehicleService {

    private final VehicleRepository repo;

    public List<Vehicle> listActive() {
        return repo.findByStatus("ACTIVE");
    }

    public Vehicle getById(Long id) {
        return repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Vehicle not found: " + id));
    }

    @Transactional
    public Vehicle create(VehicleRequest req) {
        Vehicle v = new Vehicle();
        v.setTenantId(TenantContext.get());
        v.setOwner(req.getOwner());
        v.setVendorId(req.getVendorId());
        v.setPlateNumber(req.getPlateNumber());
        v.setDisplayName(req.getDisplayName());
        v.setVehicleType(req.getVehicleType());
        return repo.save(v);
    }

    @Transactional
    public Vehicle update(Long id, VehicleRequest req) {
        Vehicle v = getById(id);
        v.setOwner(req.getOwner());
        v.setVendorId(req.getVendorId());
        v.setPlateNumber(req.getPlateNumber());
        v.setDisplayName(req.getDisplayName());
        v.setVehicleType(req.getVehicleType());
        return repo.save(v);
    }

    @Transactional
    public void deactivate(Long id) {
        Vehicle v = getById(id);
        v.setStatus("INACTIVE");
        repo.save(v);
    }
}
