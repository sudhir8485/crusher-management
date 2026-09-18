package com.dsp.crusher.repository;

import com.dsp.crusher.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {

    @Query(value = "SELECT * FROM users WHERE email = ?1 AND status = 'ACTIVE' LIMIT 1",
           nativeQuery = true)
    Optional<User> findByEmailNative(String email);

    Optional<User> findByEmailAndTenantId(String email, Long tenantId);

    Optional<User> findByIdAndTenantId(Long id, Long tenantId);

    List<User> findByTenantId(Long tenantId);

    // Global email uniqueness check — users has NO FORCE RLS so crusher_admin sees all tenants.
    // Used at creation/update time to catch cross-tenant duplicates before the DB constraint does.
    boolean existsByEmail(String email);

    // Admin service queries — crusher_admin bypasses RLS on users so these are cross-tenant safe
    Optional<User> findFirstByTenantIdAndRole(Long tenantId, String role);

    List<User> findByTenantIdAndRoleAndStatus(Long tenantId, String role, String status);
}
