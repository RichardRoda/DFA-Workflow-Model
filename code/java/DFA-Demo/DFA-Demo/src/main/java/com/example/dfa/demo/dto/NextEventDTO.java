/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.example.dfa.demo.dto;

import java.io.Serializable;
import java.util.Objects;

/**
 *
 * @author Richard
 */
public class NextEventDTO implements Serializable {
    Long    employeeId;
    Long    dfaWorkflowId;
    Integer eventTyp;
    Integer dfaStateId;
    String commentTx;

    public Integer getEventTyp() {
        return eventTyp;
    }

    public void setEventTyp(Integer eventTyp) {
        this.eventTyp = eventTyp;
    }

    public String getCommentTx() {
        return commentTx;
    }

    public void setCommentTx(String commentTx) {
        this.commentTx = commentTx;
    }
    
    public String getModBy() {
        return "APPUSER";
    }

    @Override
    public int hashCode() {
        int hash = 5;
        hash = 67 * hash + Objects.hashCode(this.employeeId);
        hash = 67 * hash + Objects.hashCode(this.dfaWorkflowId);
        hash = 67 * hash + Objects.hashCode(this.eventTyp);
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
        final NextEventDTO other = (NextEventDTO) obj;
        if (!Objects.equals(this.employeeId, other.employeeId)) {
            return false;
        }
        if (!Objects.equals(this.dfaWorkflowId, other.dfaWorkflowId)) {
            return false;
        }
        if (!Objects.equals(this.eventTyp, other.eventTyp)) {
            return false;
        }
        return true;
    }
    
    public Long getEmployeeId() {
        return employeeId;
    }

    public void setEmployeeId(Long employeeId) {
        this.employeeId = employeeId;
    }

    public Long getDfaWorkflowId() {
        return dfaWorkflowId;
    }

    public void setDfaWorkflowId(Long dfaWorkflowId) {
        this.dfaWorkflowId = dfaWorkflowId;
    }
    
    public boolean getRaiseError() {
        return true;
    }
    
    public Integer getRefId() {
        return 0;
    }

    public Integer getDfaStateId() {
        return dfaStateId;
    }

    public void setDfaStateId(Integer dfaStateId) {
        this.dfaStateId = dfaStateId;
    }
    
}
