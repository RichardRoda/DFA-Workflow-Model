/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.example.dfa.demo.dto;

import java.io.Serializable;
import java.sql.Timestamp;
import java.util.Objects;

/**
 *
 * @author Richard
 */
public class WorkflowStatesDTO implements Serializable {
    Long dfaWorkflowId;
    Integer dfaStateId;
    Boolean isCurrent;
    Boolean isPassive;
    String commentTx;
    String modBy;
    Timestamp modDt;
    String eventTx;
    Boolean eventAttention;
    String stateTx;
    Boolean stateAttention;

    public Long getDfaWorkflowId() {
        return dfaWorkflowId;
    }

    public void setDfaWorkflowId(Long dfaWorkflowId) {
        this.dfaWorkflowId = dfaWorkflowId;
    }

    public Integer getDfaStateId() {
        return dfaStateId;
    }

    public void setDfaStateId(Integer dfaStateId) {
        this.dfaStateId = dfaStateId;
    }

    public Boolean getIsCurrent() {
        return isCurrent;
    }

    public void setIsCurrent(Boolean isCurrent) {
        this.isCurrent = isCurrent;
    }

    public Boolean getIsPassive() {
        return isPassive;
    }

    public void setIsPassive(Boolean isPassive) {
        this.isPassive = isPassive;
    }

    public String getCommentTx() {
        return commentTx;
    }

    public void setCommentTx(String commentTx) {
        this.commentTx = commentTx;
    }

    public String getModBy() {
        return modBy;
    }

    public void setModBy(String modBy) {
        this.modBy = modBy;
    }

    public Timestamp getModDt() {
        return modDt;
    }

    public void setModDt(Timestamp modDt) {
        this.modDt = modDt;
    }

    public String getEventTx() {
        return eventTx;
    }

    public void setEventTx(String eventTx) {
        this.eventTx = eventTx;
    }

    public Boolean getEventAttention() {
        return eventAttention;
    }

    public void setEventAttention(Boolean eventAttention) {
        this.eventAttention = eventAttention;
    }

    public String getStateTx() {
        return stateTx;
    }

    public void setStateTx(String stateTx) {
        this.stateTx = stateTx;
    }

    public Boolean getStateAttention() {
        return stateAttention;
    }

    public void setStateAttention(Boolean stateAttention) {
        this.stateAttention = stateAttention;
    }

    @Override
    public int hashCode() {
        int hash = 3;
        hash = 29 * hash + Objects.hashCode(this.dfaWorkflowId);
        hash = 29 * hash + Objects.hashCode(this.dfaStateId);
        return hash;
    }

    @Override
    public boolean equals(Object obj) {
        if (obj == null) {
            return false;
        }
        if (getClass() != obj.getClass()) {
            return false;
        }
        final WorkflowStatesDTO other = (WorkflowStatesDTO) obj;
        if (!Objects.equals(this.dfaWorkflowId, other.dfaWorkflowId)) {
            return false;
        }
        if (!Objects.equals(this.dfaStateId, other.dfaStateId)) {
            return false;
        }
        return true;
    }
    

}
