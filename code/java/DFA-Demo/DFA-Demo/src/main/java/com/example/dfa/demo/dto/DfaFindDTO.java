/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.example.dfa.demo.dto;

import java.io.Serializable;

/**
 *
 * @author rodare
 */
public class DfaFindDTO implements Serializable {
    
    Long employeeId;
    Long workflowId;
    Integer workflowTyp;
    Boolean active = true;
    String likeLastNm;
    String likeFirstNm;
    String likeMiddleNm;
    String likeStreetNm;
    String likeCityNm;
    Integer stateId;
    String phoneNum;
    String likeEmailAddr;

    public DfaFindDTO(Long employeeId, Long workflowId) {
        this.employeeId = employeeId;
        this.workflowId = workflowId;
    }

    public DfaFindDTO(Long workflowId) {
        this.workflowId = workflowId;
    }

    public DfaFindDTO() {
    }

    public Long getEmployeeId() {
        return employeeId;
    }

    public void setEmployeeId(Long employeeId) {
        this.employeeId = employeeId;
    }

    public Long getWorkflowId() {
        return workflowId;
    }

    public void setWorkflowId(Long workflowId) {
        this.workflowId = workflowId;
    }

    public Integer getWorkflowTyp() {
        return workflowTyp;
    }

    public void setWorkflowTyp(Integer workflowTyp) {
        this.workflowTyp = workflowTyp;
    }

    public Boolean getActive() {
        return active;
    }

    public void setActive(Boolean active) {
        this.active = active;
    }

    public String getLikeLastNm() {
        return likeLastNm;
    }

    public void setLikeLastNm(String likeLastNm) {
        this.likeLastNm = likeLastNm;
    }

    public String getLikeFirstNm() {
        return likeFirstNm;
    }

    public void setLikeFirstNm(String likeFirstNm) {
        this.likeFirstNm = likeFirstNm;
    }

    public String getLikeMiddleNm() {
        return likeMiddleNm;
    }

    public void setLikeMiddleNm(String likeMiddleNm) {
        this.likeMiddleNm = likeMiddleNm;
    }

    public String getLikeStreetNm() {
        return likeStreetNm;
    }

    public void setLikeStreetNm(String likeStreetNm) {
        this.likeStreetNm = likeStreetNm;
    }

    public String getLikeCityNm() {
        return likeCityNm;
    }

    public void setLikeCityNm(String likeCityNm) {
        this.likeCityNm = likeCityNm;
    }

    public Integer getStateId() {
        return stateId;
    }

    public void setStateId(Integer stateId) {
        this.stateId = stateId;
    }

    public String getPhoneNum() {
        return phoneNum;
    }

    public void setPhoneNum(String phoneNum) {
        this.phoneNum = phoneNum;
    }

    public String getLikeEmailAddr() {
        return likeEmailAddr;
    }

    public void setLikeEmailAddr(String likeEmailAddr) {
        this.likeEmailAddr = likeEmailAddr;
    }
}
