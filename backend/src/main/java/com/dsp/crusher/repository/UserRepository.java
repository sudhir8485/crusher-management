package com.dsp.crusher.repository;

import com.dsp.crusher.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {

    @Query(value = "SELECT * FROM users WHERE email = ?1 AND status = 'ACTIVE' LIMIT 1",
           nativeQuery = true)
    Optional<User> findByEmailNative(String email);

    Optional<User> findByEmailAndTenantId(String email, Long tenantId);
}
