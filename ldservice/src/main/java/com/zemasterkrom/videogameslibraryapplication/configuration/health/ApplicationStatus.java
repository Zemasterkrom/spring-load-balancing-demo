package com.zemasterkrom.videogameslibraryapplication.configuration.health;


import com.netflix.appinfo.InstanceInfo;

import java.util.Objects;

/**
 * Bean representing the actuator status of a Spring application using the Actuator health endpoint
 */
public class ApplicationStatus implements Cloneable {

    private InstanceInfo.InstanceStatus status;

    public ApplicationStatus() {
        this.setStatus("UNKNOWN");
    }

    public InstanceInfo.InstanceStatus getStatus() {
        return this.status;
    }

    public void setStatus(String status) {
        try {
            this.status = InstanceInfo.InstanceStatus.valueOf(status);
        } catch (IllegalStateException e) {
            this.status = InstanceInfo.InstanceStatus.UNKNOWN;
        }
    }

    public void setStatus(InstanceInfo.InstanceStatus status) {
        this.status = status;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        ApplicationStatus that = (ApplicationStatus) o;
        return status == that.status;
    }

    @Override
    public int hashCode() {
        return Objects.hash(status);
    }

    @Override
    public ApplicationStatus clone() {
        ApplicationStatus as = new ApplicationStatus();

        try {
            return (ApplicationStatus) super.clone();
        } catch (CloneNotSupportedException e) {
            e.printStackTrace();
        }

        return as;
    }
}
