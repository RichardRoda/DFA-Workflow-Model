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
public class SelectedEventsDTO implements Serializable {
    Integer eventTyp;
    String  eventTx;

    public Integer getEventTyp() {
        return eventTyp;
    }

    public void setEventTyp(Integer eventTyp) {
        this.eventTyp = eventTyp;
    }

    public String getEventTx() {
        return eventTx;
    }

    public void setEventTx(String eventTx) {
        this.eventTx = eventTx;
    }

    @Override
    public int hashCode() {
        int hash = 7;
        hash = 47 * hash + Objects.hashCode(this.eventTyp);
        return hash;
    }

    @Override
    public boolean equals(Object obj) {
        if (obj == null) {
            return false;
        }
        if (obj == this) {
            return true;
        }
        if (getClass() != obj.getClass()) {
            return false;
        }
        final SelectedEventsDTO other = (SelectedEventsDTO) obj;
        if (!Objects.equals(this.eventTyp, other.eventTyp)) {
            return false;
        }
        return true;
    }
    

}
